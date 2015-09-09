ResourceWriter = require "./ResourceWriter"
LatexRunner = require "./LatexRunner"
OutputFileFinder = require "./OutputFileFinder"
OutputCacheManager = require "./OutputCacheManager"
Settings = require("settings-sharelatex")
Path = require "path"
logger = require "logger-sharelatex"
Metrics = require "./Metrics"
child_process = require "child_process"
CommandRunner = require(Settings.clsi?.commandRunner or "./CommandRunner")
fs = require("fs")

module.exports = CompileManager =
	doCompile: (request, callback = (error, outputFiles) ->) ->
		compileDir = Path.join(Settings.path.compilesDir, request.project_id)

		timer = new Metrics.Timer("write-to-disk")
		logger.log project_id: request.project_id, "starting compile"
		ResourceWriter.syncResourcesToDisk request.project_id, request.resources, compileDir, (error) ->
			return callback(error) if error?
			logger.log project_id: request.project_id, time_taken: Date.now() - timer.start, "written files to disk"
			timer.done()

			timer = new Metrics.Timer("run-compile")
			Metrics.inc("compiles")
			LatexRunner.runLatex request.project_id, {
				directory: compileDir
				mainFile:  request.rootResourcePath
				compiler:  request.compiler
				timeout:   request.timeout
			}, (error) ->
				return callback(error) if error?
				logger.log project_id: request.project_id, time_taken: Date.now() - timer.start, "done compile"
				timer.done()

				OutputFileFinder.findOutputFiles request.resources, compileDir, (error, outputFiles) ->
					return callback(error) if error?
					OutputCacheManager.saveOutputFiles outputFiles, compileDir,  (error, newOutputFiles) ->
						callback null, newOutputFiles
	
	clearProject: (project_id, _callback = (error) ->) ->
		callback = (error) ->
			_callback(error)
			_callback = () ->

		compileDir = Path.join(Settings.path.compilesDir, project_id)
		proc = child_process.spawn "rm", ["-r", compileDir]

		proc.on "error", callback

		stderr = ""
		proc.stderr.on "data", (chunk) -> stderr += chunk.toString()

		proc.on "close", (code) ->
			if code == 0
				return callback(null)
			else
				return callback(new Error("rm -r #{compileDir} failed: #{stderr}"))

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

	_parseWordcountFromOutput: (output) ->
		results = {
			encode: ""
			textWords: 0
			headWords: 0
			outside: 0
			headers: 0
			elements: 0
			mathInline: 0
			mathDisplay: 0
		}
		for line in output.split("\n")
			[data, info] = line.split(":")
			if data.indexOf("Encoding") > -1
				results['encode'] = info.trim()
			if data.indexOf("in text") > -1
				results['textWords'] = parseInt(info, 10)
			if data.indexOf("in head") > -1
				results['headWords'] = parseInt(info, 10)
			if data.indexOf("outside") > -1
				results['outside'] = parseInt(info, 10)
			if data.indexOf("of head") > -1
				results['headers'] = parseInt(info, 10)
			if data.indexOf("float") > -1
				results['elements'] = parseInt(info, 10)
			if data.indexOf("inlines") > -1
				results['mathInline'] = parseInt(info, 10)
			if data.indexOf("displayed") > -1
				results['mathDisplay'] = parseInt(info, 10)

		return results

	wordcount: (project_id, file_name, callback = (error, pdfPositions) ->) ->
		file_path = "$COMPILE_DIR/" + file_name
		command = [ "texcount", file_path, "-out=" + file_path + ".wc"]
		directory = Path.join(Settings.path.compilesDir, project_id)
		timeout = 10 * 1000

		CommandRunner.run project_id, command, directory, timeout, (error) ->
			return callback(error) if error?
			stdout = fs.readFileSync(directory + "/" + file_name + ".wc", "utf-8")
			callback null, CompileManager._parseWordcountFromOutput(stdout)
