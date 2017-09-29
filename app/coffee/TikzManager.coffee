fs = require "fs"
Path = require "path"
ResourceWriter = require "./ResourceWriter"
SafeReader = require "./SafeReader"
logger = require "logger-sharelatex"

# for \tikzexternalize to work the main file needs to match the
# jobname.  Since we set the -jobname to output, we have to create a
# copy of the main file as 'output.tex'.

module.exports = TikzManager =

	createTikzFileIfRequired: (compileDir, rootResourcePath, resources, callback = (err)->) ->
		# first see if we need to create an output.tex file
		needsOutputFile = TikzManager.needsOutputFile(rootResourcePath, resources)
		if needsOutputFile is "missing"
			# it's an incremental compile, and the file content has not been
			# sent in the request, so we need to look at the existing
			# content on disk and retry.
			TikzManager.loadRootResource compileDir, rootResourcePath, (err, rootResource) ->
				return callback(err) if err?
				TikzManager.createTikzFileIfRequired compileDir, rootResourcePath, [rootResource], callback
		else
			# if we get here, we have examined the main file and know whether
			# it contains \tikzexternalize or not.
			if needsOutputFile
				TikzManager.injectOutputFile compileDir, rootResourcePath, callback
			else
				return callback()

	loadRootResource: (compileDir, rootResourcePath, callback = (err)->) ->
		ResourceWriter.checkPath compileDir, rootResourcePath, (error, path) ->
			return callback(error) if error?
			# read the first 64KB of the main file
			SafeReader.readFile path, 65536, "utf8", (err, content) ->
				return callback(err) if err?
				rootResource = {path: rootResourcePath, content: content}
				callback(null, rootResource)

	needsOutputFile: (rootResourcePath, resources) ->
		# if there's already an output.tex file, we don't want to touch it
		for resource in resources
			if resource.path is "output.tex"
				return false
		# if there's no output.tex, see if we are using tikz/pgf in the main file
		for resource in resources
			if resource.path is rootResourcePath
				return TikzManager._includesTikz (resource)
		# otherwise false
		return false

	_includesTikz: (resource) ->
		# check if we are using tikz externalize
		content = resource.content?.slice(0,65536)
		if !content? # resource has no content in incremental compile
			return "missing"
		else if content?.indexOf("\\tikzexternalize") >= 0
			return true
		else
			return false

	injectOutputFile: (compileDir, mainFile, callback = (error) ->) ->
		ResourceWriter.checkPath compileDir, mainFile, (error, path) ->
			return callback(error) if error?
			fs.readFile path, "utf8", (error, content) ->
				return callback(error) if error?
				logger.log compileDir: compileDir, mainFile: mainFile, "copied file to ouput.tex for tikz"
				# use wx flag to ensure that output file does not already exist
				fs.writeFile Path.join(compileDir, "output.tex"), content, {flag:'wx'}, callback
