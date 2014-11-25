UrlCache = require "./UrlCache"
Path = require "path"
fs = require "fs"
async = require "async"
mkdirp = require "mkdirp"
OutputFileFinder = require "./OutputFileFinder"
Metrics = require "./Metrics"
CommandRunner = require "./CommandRunner"

module.exports = ResourceWriter =
	syncResourcesToDisk: (project_id, resources, callback = (error) ->) ->
		@_removeExtraneousFiles project_id, resources, (error) =>
			return callback(error) if error?
			jobs = for resource in resources
				do (resource) =>
					(callback) => @_writeResourceToDisk(project_id, resource, callback)
			async.series jobs, callback

	_removeExtraneousFiles: (project_id, resources, _callback = (error) ->) ->
		timer = new Metrics.Timer("unlink-output-files")
		callback = (error) ->
			timer.done()
			_callback(error)

		OutputFileFinder.findOutputFiles project_id, resources, (error, outputFiles) ->
			return callback(error) if error?

			jobs = []
			for file in outputFiles or []
				do (file) ->
					path = file.path
					should_delete = true
					if path.match(/^output\./) or path.match(/\.aux$/)
						should_delete = false
					if path == "output.pdf" or path == "output.dvi" or path == "output.log"
						should_delete = true
					if should_delete
						jobs.push (callback) ->
							CommandRunner.deleteFileIfNotDirectory project_id, path, callback

			async.series jobs, callback

	_writeResourceToDisk: (project_id, resource, callback = (error) ->) ->
		if resource.url?
			UrlCache.getUrlStream project_id, resource.url, resource.modified, (error, stream) ->
				return callback(error) if error?
				CommandRunner.addFileFromStream project_id, resource.path, stream, callback
		else
			CommandRunner.addFileFromContent project_id, resource.path, resource.content, callback

