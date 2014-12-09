SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../app/js/FilesystemManager'
EventEmitter = require("events").EventEmitter

describe "FilesystemManager", ->
	beforeEach ->
		@FilesystemManager = SandboxedModule.require modulePath, requires:
			"settings-sharelatex": @Settings = { path: compilesDir: "/compiles/dir" }
			"logger-sharelatex": @logger = { log: sinon.stub(), warn: sinon.stub() }
			"child_process": @child_process = {}
		@project_id = "mock-project-id-123"
		@callback = sinon.stub()

	describe "clearProject", ->
		describe "succesfully", ->
			beforeEach ->
				@Settings.compileDir = "compiles"
				@proc = new EventEmitter()
				@proc.stdout = new EventEmitter()
				@proc.stderr = new EventEmitter()
				@child_process.spawn = sinon.stub().returns(@proc)
				@FilesystemManager.clearProject @project_id, @callback
				@proc.emit "close", 0

			it "should remove the project directory", ->
				@child_process.spawn
					.calledWith("rm", ["-r", "#{@Settings.path.compilesDir}/#{@project_id}"])
					.should.equal true

			it "should call the callback", ->
				@callback.called.should.equal true

		describe "with a non-success status code", ->
			beforeEach ->
				@Settings.compileDir = "compiles"
				@proc = new EventEmitter()
				@proc.stdout = new EventEmitter()
				@proc.stderr = new EventEmitter()
				@child_process.spawn = sinon.stub().returns(@proc)
				@FilesystemManager.clearProject @project_id, @callback
				@proc.stderr.emit "data", @error = "oops"
				@proc.emit "close", 1

			it "should remove the project directory", ->
				@child_process.spawn
					.calledWith("rm", ["-r", "#{@Settings.path.compilesDir}/#{@project_id}"])
					.should.equal true

			it "should call the callback with an error from the stderr", ->
				@callback
					.calledWith(new Error())
					.should.equal true

				@callback.args[0][0].message.should.equal "rm -r #{@Settings.path.compilesDir}/#{@project_id} failed: #{@error}"

	describe "getAllFiles", ->
		beforeEach ->
			@proc = new EventEmitter()
			@proc.stdout = new EventEmitter()
			@child_process.spawn = sinon.stub().returns @proc
			@directory = @Settings.path.compilesDir + "/" + @project_id
			@FilesystemManager.getAllFiles @project_id, @callback
			
		describe "successfully", ->
			beforeEach ->
				@proc.stdout.emit(
					"data",
					["#{@directory}/main.tex", "#{@directory}/chapters/chapter1.tex"].join("\n") + "\n"
				)
				@proc.emit "close", 0
				
			it "should call the callback with the relative file paths", ->
				@callback.calledWith(
					null,
					["main.tex", "chapters/chapter1.tex"]
				).should.equal true

		describe "when the directory doesn't exist", ->
			beforeEach ->
				@proc.emit "close", 1
				
			it "should call the callback with a blank array", ->
				@callback.calledWith(
					null,
					[]
				).should.equal true