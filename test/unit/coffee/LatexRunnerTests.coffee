SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../app/js/LatexRunner'
Path = require "path"

describe "LatexRunner", ->
	beforeEach ->
		@LatexRunner = SandboxedModule.require modulePath, requires:
			"settings-sharelatex": @Settings =
				docker:
					socketPath: "/var/run/docker.sock"
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
			"./Metrics":
				Timer: class Timer
					done: () ->
			"./CommandRunner": @CommandRunner = {}

		@mainFile  = "main-file.tex"
		@compiler  = "pdflatex"
		@callback  = sinon.stub()
		@project_id = "project-id-123"

	describe "runLatex", ->
		beforeEach ->
			@CommandRunner.run = sinon.stub().callsArg(4)

		describe "normally", ->
			beforeEach ->
				@LatexRunner.runLatex @project_id,
					mainFile:  @mainFile
					compiler:  @compiler
					timeout:   timeout = 42000
					processes: @processes = 42
					memory:    @memory = 1024
					cpu_shares: @cpu_shares = 2048
					@callback

			it "should run the latex command with the given limits", ->
				@CommandRunner.run
					.calledWith(@project_id, sinon.match.any, sinon.match.any, {
						timeout: @timeout
						memory: @memory
						cpu_shares: @cpu_shares
						processes: @processes
					})
					.should.equal true

		describe "with an .Rtex main file", ->
			beforeEach ->
				@LatexRunner.runLatex @project_id,
					mainFile:  "main-file.Rtex"
					compiler:  @compiler
					@callback

			it "should run the latex command on the equivalent .tex file", ->
				command = @CommandRunner.run.args[0][1]
				mainFile = command.slice(-1)[0]
				mainFile.should.equal "$COMPILE_DIR/main-file.tex"

