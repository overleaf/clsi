SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
expect = require("chai").expect
modulePath = require('path').join __dirname, '../../../app/js/CompileManager'
tk = require("timekeeper")
EventEmitter = require("events").EventEmitter
Path = require "path"

describe "CompileManager", ->
	beforeEach ->
		@CompileManager = SandboxedModule.require modulePath, requires:
			"./LatexRunner": @LatexRunner = {}
			"./ResourceWriter": @ResourceWriter = {}
			"./OutputFileFinder": @OutputFileFinder = {}
			"./FilesystemManager": @FilesystemManager = {}
			"./RealTimeApiManager": @RealTimeApiManager = {}
			"settings-sharelatex": @Settings = { path: compilesDir: "/compiles/dir" }
			"logger-sharelatex": @logger = { log: sinon.stub() }
			"child_process": @child_process = {}
			"./Metrics": {
				Timer: class Timer
					done: sinon.stub()
				inc: sinon.stub()
			}
		@callback = sinon.stub()

	describe "doCompile", ->
		beforeEach ->
			@output_files = [{
				path: "output.log"
				type: "log"
			}, {
				path: "output.pdf"
				type: "pdf"
			}]
			@stream = new EventEmitter()
			@request =
				resources: @resources = "mock-resources"
				rootResourcePath: @rootResourcePath = "main.tex"
				project_id: @project_id = "project-id-123"
				session_id: @session_id = "session-id-123"
				compiler: @compiler = "pdflatex"
				command: @command = []
				package: @package = ""
				env: @env = { "mock": "env" }
				timeout: @timeout = 42000
				processes: @processes = 42
				memory:    @memory = 1024
				cpu_shares: @cpu_shares = 2048
			@Settings.compileDir = "compiles"
			@compileDir = "#{@Settings.path.compilesDir}/#{@project_id}"
			@FilesystemManager.initProject = sinon.stub().callsArg(1)
			@ResourceWriter.syncResourcesToDisk = sinon.stub().callsArg(2)
			@LatexRunner.runLatex = sinon.stub().callsArgWith(2, null, @stream)
			@RealTimeApiManager.bufferMessageForSending = sinon.stub()
			@OutputFileFinder.findOutputFiles = sinon.stub().callsArgWith(2, null, @output_files)
			@CompileManager.doCompile @request, @callback
			@stream.emit "data", @message = { "mock": "message" }
			
			@CompileManager.INPROGRESS_STREAMS["#{@project_id}:#{@session_id}"].should.equal @stream
			@stream.emit "end"
			
		it "should init the project", ->
			@FilesystemManager.initProject
				.calledWith(@project_id)
				.should.equal true

		it "should write the resources to disk", ->
			@ResourceWriter.syncResourcesToDisk
				.calledWith(@project_id, @resources)
				.should.equal true

		it "should run LaTeX with the given limits", ->
			@LatexRunner.runLatex
				.calledWith(@project_id, {
					mainFile:  @rootResourcePath
					compiler:  @compiler
					command:   @command
					package:   @package
					env:       @env
					timeout:   @timeout
					processes: @processes = 42
					memory:    @memory = 1024
					cpu_shares: @cpu_shares = 2048
				})
				.should.equal true

		it "should find the output files", ->
			@OutputFileFinder.findOutputFiles
				.calledWith(@project_id, @resources)
				.should.equal true
				
		it "should send emitted messages to the real time api", ->
			@RealTimeApiManager.bufferMessageForSending
				.calledWith(@project_id, @message)
				.should.equal true

		it "should return the output files", ->
			@callback.calledWith(null, @output_files).should.equal true
			
		it "should remove the stream from INPROGRESS_STREAMS", ->
			stream = @CompileManager.INPROGRESS_STREAMS["#{@project_id}:#{@session_id}"]
			expect(stream).to.be.undefined
	
	describe "stopCompile", ->
		beforeEach ->
			@project_id = "project-id-123"
			@session_id = "session-id-123"
		
		describe "when the session_id exists", ->
			beforeEach ->
				@stream =
					emit: sinon.stub()
				@CompileManager.INPROGRESS_STREAMS["#{@project_id}:#{@session_id}"] = @stream
				@CompileManager.stopCompile @project_id, @session_id, @callback
			
			it "should send a kill signal to the stream", ->
				@stream.emit.calledWith("kill").should.equal true
				
			it "should call the callback", ->
				@callback.called.should.equal true
			
		describe "when the session_id does not exist", ->
			beforeEach ->
				@CompileManager.stopCompile @project_id, @session_id, @callback
			
			it "should call the callback with an error", ->
				error = @callback.args[0][0]
				error.statusCode.should.equal 404

	describe "syncing", ->
		beforeEach ->
			@page = 1
			@h = 42.23
			@v = 87.56
			@width = 100.01
			@height = 234.56
			@line = 5
			@column = 3
			@file_name = "main.tex"
			@child_process.execFile = sinon.stub()
			@Settings.path.synctexBaseDir = (project_id) => "#{@Settings.path.compilesDir}/#{@project_id}"

		describe "syncFromCode", ->
			beforeEach ->
				@child_process.execFile.callsArgWith(3, null, @stdout = "NODE\t#{@page}\t#{@h}\t#{@v}\t#{@width}\t#{@height}\n", "")
				@CompileManager.syncFromCode @project_id, @file_name, @line, @column, @callback

			it "should execute the synctex binary", ->
				bin_path = Path.resolve(__dirname + "/../../../bin/synctex")
				synctex_path = "#{@Settings.path.compilesDir}/#{@project_id}/output.pdf"
				file_path = "#{@Settings.path.compilesDir}/#{@project_id}/#{@file_name}"
				@child_process.execFile
					.calledWith(bin_path, ["code", synctex_path, file_path, @line, @column], timeout: 10000)
					.should.equal true

			it "should call the callback with the parsed output", ->
				@callback
					.calledWith(null, [{
						page: @page
						h: @h
						v: @v
						height: @height
						width: @width
					}])
					.should.equal true

		describe "syncFromPdf", ->
			beforeEach ->
				@child_process.execFile.callsArgWith(3, null, @stdout = "NODE\t#{@Settings.path.compilesDir}/#{@project_id}/#{@file_name}\t#{@line}\t#{@column}\n", "")
				@CompileManager.syncFromPdf @project_id, @page, @h, @v, @callback

			it "should execute the synctex binary", ->
				bin_path = Path.resolve(__dirname + "/../../../bin/synctex")
				synctex_path = "#{@Settings.path.compilesDir}/#{@project_id}/output.pdf"
				@child_process.execFile
					.calledWith(bin_path, ["pdf", synctex_path, @page, @h, @v], timeout: 10000)
					.should.equal true

			it "should call the callback with the parsed output", ->
				@callback
					.calledWith(null, [{
						file: @file_name
						line: @line
						column: @column
					}])
					.should.equal true