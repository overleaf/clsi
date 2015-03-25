ResourceWriter = require "./ResourceWriter"
LatexRunner = require "./LatexRunner"
OutputFileFinder = require "./OutputFileFinder"
FilesystemManager = require "./FilesystemManager"
RealTimeApiManager = require "./RealTimeApiManager"
Settings = require("settings-sharelatex")
Path = require "path"
logger = require "logger-sharelatex"
Metrics = require "./Metrics"
child_process = require "child_process"

module.exports = CompileManager =
	INPROGRESS_STREAMS: {}

	doCompile: (request, _callback = (error, outputFiles, output) ->) ->
		callback = (args...) ->
			_callback(args...)
			_callback = () ->
		
		timer = new Metrics.Timer("write-to-disk")
		project_id = request.project_id
		logger.log {project_id}, "starting compile"
		FilesystemManager.initProject project_id, (error) ->
			return callback(error) if error?
			ResourceWriter.syncResourcesToDisk project_id, request.resources, (error) ->
				return callback(error) if error?
				logger.log project_id: project_id, time_taken: Date.now() - timer.start, "written files to disk"
				timer.done()

				timer = new Metrics.Timer("run-compile")
				Metrics.inc("compiles")
				LatexRunner.runLatex request.project_id, {
					mainFile:  request.rootResourcePath
					compiler:  request.compiler
					command:   request.command
					env:       request.env
					timeout:   request.timeout
					processes: request.processes
					memory:    request.memory
					cpu_shares: request.cpu_shares
				}, (error, stream) ->
					return callback(error) if error?
			
					streamId = "#{request.project_id}:#{request.session_id}"
					CompileManager.INPROGRESS_STREAMS[streamId] = stream
					
					output =
						stdout: ""
						stderr: ""
					
					msg_id = 0
					stream.on "data", (message) ->
						message.header ||= {}
						message.header.session = request.session_id
						message.header.msg_id = msg_id.toString()
						msg_id++
						logger.log {message, project_id}, "got output message"
						if message.msg_type == "stream"
							output[message.content.name] += message.content.text
						RealTimeApiManager.bufferMessageForSending project_id, message
								
					stream.on "error", callback
								
					stream.on "end", () ->
						logger.log project_id: project_id, time_taken: Date.now() - timer.start, "done compile"
						timer.done()
						delete CompileManager.INPROGRESS_STREAMS[streamId]
						OutputFileFinder.findOutputFiles project_id, request.resources, (error, outputFiles) ->
							return callback(error) if error?
							logger.log {outputFiles, project_id}, "got output files"
							callback null, outputFiles, output
	
	stopCompile: (project_id, session_id, callback = (error) ->) ->
		streamId = "#{project_id}:#{session_id}"
		stream = CompileManager.INPROGRESS_STREAMS[streamId]
		logger.log {project_id, session_id}, "stopping compile"
		if !stream?
			error = new Error("No such session")
			error.statusCode = 404
			logger.log {err: error, project_id, session_id}, "session not found"
			return callback error
		
		stream.emit "kill"
		callback()

	syncFromCode: (project_id, file_name, line, column, callback = (error, pdfPositions) ->) ->
		# If LaTeX was run in a virtual environment, the file path that synctex expects
		# might not match the file path on the host. The .synctex.gz file however, will be accessed
		# wherever it is on the host.
		base_dir = Settings.path.synctexBaseDir(project_id)
		file_path = base_dir + "/" + file_name
		synctex_path = Path.join(Settings.path.compilesDir, project_id, "output.pdf")
		CompileManager._runSynctex ["code", synctex_path, file_path, line, column], (error, stdout) ->
			return callback(error) if error?
			logger.log project_id: project_id, file_name: file_name, line: line, column: column, stdout: stdout, "synctex code output"
			callback null, CompileManager._parseSynctexFromCodeOutput(stdout)

	syncFromPdf: (project_id, page, h, v, callback = (error, filePositions) ->) ->
		base_dir = Settings.path.synctexBaseDir(project_id)
		synctex_path = Path.join(Settings.path.compilesDir, project_id, "output.pdf")
		CompileManager._runSynctex ["pdf", synctex_path, page, h, v], (error, stdout) ->
			return callback(error) if error?
			logger.log project_id: project_id, page: page, h: h, v:v, stdout: stdout, "synctex pdf output"
			callback null, CompileManager._parseSynctexFromPdfOutput(stdout, base_dir)

	_runSynctex: (args, callback = (error, stdout) ->) ->
		bin_path = Path.resolve(__dirname + "/../../bin/synctex")
		seconds = 1000
		child_process.execFile bin_path, args, timeout: 10 * seconds, (error, stdout, stderr) ->
			return callback(error) if error?
			callback(null, stdout)

	_parseSynctexFromCodeOutput: (output) ->
		results = []
		for line in output.split("\n")
			[node, page, h, v, width, height] = line.split("\t")
			if node == "NODE"
				results.push {
					page:   parseInt(page, 10)
					h:      parseFloat(h)
					v:      parseFloat(v)
					height: parseFloat(height)
					width:  parseFloat(width)
				}
		return results

	_parseSynctexFromPdfOutput: (output, base_dir) ->
		results = []
		for line in output.split("\n")
			[node, file_path, line, column] = line.split("\t")
			if node == "NODE"
				file = file_path.slice(base_dir.length + 1)
				results.push {
					file: file
					line: parseInt(line, 10)
					column: parseInt(column, 10)
				}
		return results