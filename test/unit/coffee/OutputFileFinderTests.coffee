SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../app/js/OutputFileFinder'
path = require "path"
expect = require("chai").expect

describe "OutputFileFinder", ->
	beforeEach ->
		@OutputFileFinder = SandboxedModule.require modulePath, requires:
			"./FilesystemManager": @FilesystemManager = {}
			"logger-sharelatex": @logger = {log: sinon.stub()}
		@project_id = "mock-project-id-123"
		@callback = sinon.stub()

	describe "findOutputFiles", ->
		beforeEach ->
			@output_paths = ["output.pdf", "extra/file.tex"]
			@resources = [
				path: @resource_path = "resource/path.tex"
			]
			@FilesystemManager.getAllFiles = sinon.stub().callsArgWith(1, null, @output_paths.concat([@resource_path]))
			@OutputFileFinder.findOutputFiles @project_id, @resources, (error, @outputFiles) =>
				
		it "should get all the files from the FilesystemManager", ->
			@FilesystemManager.getAllFiles
				.calledWith(@project_id)
				.should.equal true

		it "should only return the output files, not directories or resource paths", ->
			expect(@outputFiles).to.deep.equal [{
				path: "output.pdf"
				type: "pdf"
			}, {
				path: "extra/file.tex",
				type: "tex"
			}]

	
