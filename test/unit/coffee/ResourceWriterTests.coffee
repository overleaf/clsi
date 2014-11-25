SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../app/js/ResourceWriter'
path = require "path"

describe "ResourceWriter", ->
	beforeEach ->
		@ResourceWriter = SandboxedModule.require modulePath, requires:
			"fs": @fs = {}
			"wrench": @wrench = {}
			"./UrlCache" : @UrlCache = {}
			"mkdirp" : @mkdirp = sinon.stub().callsArg(1)
			"./OutputFileFinder": @OutputFileFinder = {}
			"./Metrics": @Metrics =
				Timer: class Timer
					done: sinon.stub()
			"./CommandRunner": @CommandRunner = {}
		@project_id = "project-id-123"
		@callback = sinon.stub()

	describe "syncResourcesToDisk", ->
		beforeEach ->
			@resources = [
				"resource-1-mock"
				"resource-2-mock"
				"resource-3-mock"
			]
			@ResourceWriter._writeResourceToDisk = sinon.stub().callsArg(2)
			@ResourceWriter._removeExtraneousFiles = sinon.stub().callsArg(2)
			@ResourceWriter.syncResourcesToDisk(@project_id, @resources, @callback)

		it "should remove old files", ->
			@ResourceWriter._removeExtraneousFiles
				.calledWith(@project_id, @resources)
				.should.equal true

		it "should write each resource to disk", ->
			for resource in @resources
				@ResourceWriter._writeResourceToDisk
					.calledWith(@project_id, resource)
					.should.equal true

		it "should call the callback", ->
			@callback.called.should.equal true

	describe "_removeExtraneousFiles", ->
		beforeEach ->
			@output_files = [{
				path: "output.pdf"
				type: "pdf"
			}, {
				path: "extra/file.tex"
				type: "tex"
			}, {
				path: "extra.aux"
				type: "aux"
			}]
			@resources = "mock-resources"
			@OutputFileFinder.findOutputFiles = sinon.stub().callsArgWith(2, null, @output_files)
			@CommandRunner.deleteFileIfNotDirectory = sinon.stub().callsArg(2)
			@ResourceWriter._removeExtraneousFiles(@project_id, @resources, @callback)

		it "should find the existing output files", ->
			@OutputFileFinder.findOutputFiles
				.calledWith(@project_id, @resources)
				.should.equal true

		it "should delete the output files", ->
			@CommandRunner.deleteFileIfNotDirectory
				.calledWith(@project_id, "output.pdf")
				.should.equal true

		it "should delete the extra files", ->
			@CommandRunner.deleteFileIfNotDirectory
				.calledWith(@project_id, "extra/file.tex")
				.should.equal true

		it "should not delete the extra aux files", ->
			@CommandRunner.deleteFileIfNotDirectory
				.calledWith(@project_id, "extra.aux")
				.should.equal false

		it "should call the callback", ->
			@callback.called.should.equal true

		it "should time the request", ->
			@Metrics.Timer::done.called.should.equal true

	describe "_writeResourceToDisk", ->
		describe "with a url based resource", ->
			beforeEach ->
				@resource =
					path: "main.tex"
					url: "http://www.example.com/main.tex"
					modified: Date.now()
				@UrlCache.getUrlStream = sinon.stub().callsArgWith(3, null, @stream = "mock-stream")
				@CommandRunner.addFileFromStream = sinon.stub().callsArg(3)
				@ResourceWriter._writeResourceToDisk(@project_id, @resource, @callback)

			it "should write the URL from the cache", ->
				@UrlCache.getUrlStream
					.calledWith(@project_id, @resource.url, @resource.modified)
					.should.equal true
					
			it "should add the file to the command runner", ->
				@CommandRunner.addFileFromStream
					.calledWith(@project_id, @resource.path, @stream)
					.should.equal true
			
			it "should call the callback", ->
				@callback.called.should.equal true

		describe "with a content based resource", ->
			beforeEach ->
				@resource =
					path: "main.tex"
					content: "Hello world"
				@CommandRunner.addFileFromContent = sinon.stub().callsArg(3)
				@ResourceWriter._writeResourceToDisk(@project_id, @resource, @callback)

			it "should write the contents to disk", ->
				@CommandRunner.addFileFromContent
					.calledWith(@project_id, @resource.path, @resource.content)
					.should.equal true
				
			it "should call the callback", ->
				@callback.called.should.equal true
		
		# describe "with a file path that breaks out of the root folder", ->
		# 	beforeEach ->
		# 		@resource =
		# 			path: "../../main.tex"
		# 			content: "Hello world"
		# 		@fs.writeFile = sinon.stub().callsArg(2)
		# 		@ResourceWriter._writeResourceToDisk(@project_id, @resource, @basePath, @callback)
		# 
		# 	it "should not write to disk", ->
		# 		@fs.writeFile.called.should.equal false
		# 
		# 	it "should return an error", ->
		# 		@callback
		# 			.calledWith(new Error("resource path is outside root directory"))
		# 			.should.equal true
			
			

			
