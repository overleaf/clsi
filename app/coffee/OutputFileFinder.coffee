FilesystemManager = require "./FilesystemManager"

module.exports = OutputFileFinder =
	findOutputFiles: (project_id, resources, callback = (error, outputFiles) ->) ->
		inputFiles = {}
		for resource in resources
			inputFiles[resource.path] = true

		FilesystemManager.getAllFiles project_id, (error, allFiles) ->
			jobs = []
			outputFiles = allFiles.filter (file) -> !inputFiles[file]
			callback null, outputFiles.map (file) ->
				{
					path: file
					type: file.match(/\.([^\.]+)$/)?[1]
				}

