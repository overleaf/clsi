child_process = require("child_process")
logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
Path = require "path"
wrench = require "wrench"
mkdirp = require "mkdirp"
fs = require "fs"
async = require "async"

module.exports = CommandRunner =
	run: (project_id, command, limits = {}, callback = (error, output) ->) ->
		directory = Path.join(settings.path.compilesDir, project_id)

		command = (arg.replace('$COMPILE_DIR', directory) for arg in command)
		logger.log project_id: project_id, command: command, directory: directory, "running command"
		logger.warn "timeouts and sandboxing are not enabled with CommandRunner"

		proc = child_process.spawn command[0], command.slice(1), cwd: directory
		
		stdout = ""
		stderr = ""
		proc.stdout.on "data", (chunk) -> stdout += chunk.toString()
		proc.stderr.on "data", (chunk) -> stderr += chunk.toString()
		
		proc.on "close", () ->
			callback(null, {stdout, stderr})
			
	initProject: (project_id, callback = (error) ->) ->
		directory = Path.join(settings.path.compilesDir, project_id)
		mkdirp directory, callback
			
	_getNormalizedPath: (project_id, filePath, callback = (error, path) ->) ->
		basePath = Path.join(settings.path.compilesDir, project_id)
		path = Path.normalize(Path.join(basePath, filePath))
		if (path.slice(0, basePath.length) != basePath)
			return callback new Error("resource path is outside root directory")
		callback null, path
			
	deleteFileIfNotDirectory: (project_id, filePath, callback = (error) ->) ->
		CommandRunner._getNormalizedPath project_id, filePath, (error, path) ->
			return callback(error) if error?
			fs.stat path, (error, stat) ->
				return callback(error) if error?
				if stat.isFile()
					fs.unlink path, callback
				else
					callback()
		
	addFiles: (project_id, files, callback = (error) ->) ->
		async.eachSeries files,
			(file, callback) ->
				if file.content?
					CommandRunner._addFileFromContent project_id, file.path, file.content, callback
				else if file.src?
					CommandRunner._addFileStream project_id, file.path, fs.createReadStream(file.src), callback
			callback
		
	_addFileFromStream: (project_id, filePath, readStream, callback = (error) ->) ->
		CommandRunner._getNormalizedPath project_id, filePath, (error, path) ->
			return callback(error) if error?
			mkdirp Path.dirname(path), (error) ->
				return callback(error) if error?
				callbackOnce = (error) ->
					callback(error)
					callback = () ->
				writeStream = fs.createWriteStream(path)
				writeStream.on "error", callbackOnce
				writeStream.on "close", () -> callbackOnce()
				readStream.on "error", callbackOnce
				readStream.pipe(writeStream)
			
	_addFileFromContent: (project_id, filePath, content, callback = (error) ->) ->
		CommandRunner._getNormalizedPath project_id, filePath, (error, path) ->
			return callback(error) if error?
			mkdirp Path.dirname(path), (error) ->
				return callback(error) if error?
				fs.writeFile path, content, callback
			
	clearProject: (project_id, _callback = (error) ->) -> 
		callback = (error) ->
			_callback(error)
			_callback = () ->

		directory = Path.join(settings.path.compilesDir, project_id)
		proc = child_process.spawn "rm", ["-r", directory]

		proc.on "error", callback

		stderr = ""
		proc.stderr.on "data", (chunk) -> stderr += chunk.toString()

		proc.on "close", (code) ->
			if code == 0
				return callback(null)
			else
				return callback(new Error("rm -r #{directory} failed: #{stderr}"))

	getAllFiles: (project_id, callback = (error, files) ->) ->
		directory = Path.join(settings.path.compilesDir, project_id)
		
		CommandRunner._getAllEntities directory, (error, allEntities) ->
			return callback(error) if error?
			
			isFile = (file, callback = (isDirectory) ->) ->
				fs.stat Path.join(directory, file), (error, stat) ->
					return callback(false) if error?
					if stat.isFile()
						callback(true)
					else
						callback(false)
			
			async.filterSeries allEntities, isFile, (files) ->
				callback null, files

	_getAllEntities: (directory, _callback = (error, outputFiles) ->) ->
		callback = (error, outputFiles) ->
			_callback(error, outputFiles)
			_callback = () ->

		outputFiles = []
		wrench.readdirRecursive directory, (error, files) =>
			if error?
				if error.code == "ENOENT"
					# Directory doesn't exist, which is not a problem
					return callback(null, [])
				else
					return callback(error)

			# readdirRecursive returns multiple times and finishes with a null response
			if !files?
				return callback(null, outputFiles)

			for file in files
				outputFiles.push file

