SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../app/js/RequestParser'
tk = require("timekeeper")

describe "RequestParser", ->
	beforeEach ->
		tk.freeze()
		@callback = sinon.stub()
		@validResource =
			path: "main.tex"
			date: "12:00 01/02/03"
			content: "Hello world"
		@validRequest =
			compile:
				request_id: "request-id"
				token: "token-123"
				options:
					compiler:   "pdflatex"
					timeout:    42
					memory:     1024
					cpu_shares: 2048
					processes:  1024
				resources: []
		@RequestParser = SandboxedModule.require modulePath
	
	afterEach ->
		tk.reset()

	describe "without a top level object", ->
		beforeEach ->
			@RequestParser.parse [], @callback

		it "should return an error", ->
			@callback.calledWith(new Error "top level object should have a compile attribute")
				.should.equal true

	describe "without a compile attribute", ->
		beforeEach ->
			@RequestParser.parse {}, @callback

		it "should return an error", ->
			@callback.calledWith(new Error "top level object should have a compile attribute")
				.should.equal true

	describe "without a valid compiler", ->
		beforeEach ->
			@validRequest.compile.options.compiler = "not-a-compiler"
			@RequestParser.parse @validRequest, @callback

		it "should return an error", ->
			@callback.calledWith(new Error "compiler attribute should be one of: pdflatex, latex, xelatex, lualatex, python, r, command, apt-get-install")
				.should.equal true

	describe "without a compiler specified", ->
		beforeEach ->
			delete @validRequest.compile.options.compiler
			@RequestParser.parse @validRequest, (error, @data) =>
		
		it "should set the compiler to pdflatex by default", ->
			@data.compiler.should.equal "pdflatex"

	describe "without a timeout specified", ->
		beforeEach ->
			delete @validRequest.compile.options.timeout
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the timeout to MAX_TIMEOUT", ->
			@data.timeout.should.equal @RequestParser.MAX_TIMEOUT * 1000

	describe "with a timeout larger than the maximum", ->
		beforeEach ->
			@validRequest.compile.options.timeout = @RequestParser.MAX_TIMEOUT + 1
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the timeout to MAX_TIMEOUT", ->
			@data.timeout.should.equal @RequestParser.MAX_TIMEOUT * 1000

	describe "with a timeout", ->
		beforeEach ->
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the timeout (in milliseconds)", ->
			@data.timeout.should.equal @validRequest.compile.options.timeout * 1000

	describe "without a cpu_shares limit specified", ->
		beforeEach ->
			delete @validRequest.compile.options.cpu_shares
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the cpu_shares limit to MAX_CPU_SHARES", ->
			@data.cpu_shares.should.equal @RequestParser.MAX_CPU_SHARES

	describe "with a cpu_shares limit larger than the maximum", ->
		beforeEach ->
			@validRequest.compile.options.cpu_shares = @RequestParser.MAX_CPU_SHARES + 1
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the cpu_shares limit to MAX_CPU_SHARES", ->
			@data.cpu_shares.should.equal @RequestParser.MAX_CPU_SHARES

	describe "with a cpu_shares limit", ->
		beforeEach ->
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the cpu_shares limit (in milliseconds)", ->
			@data.cpu_shares.should.equal @validRequest.compile.options.cpu_shares

	describe "without a processes limit specified", ->
		beforeEach ->
			delete @validRequest.compile.options.processes
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the processes limit to MAX_PROCESSES", ->
			@data.processes.should.equal @RequestParser.MAX_PROCESSES

	describe "with a processes limit larger than the maximum", ->
		beforeEach ->
			@validRequest.compile.options.processes = @RequestParser.MAX_PROCESSES + 1
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the processes limit to MAX_PROCESSES", ->
			@data.processes.should.equal @RequestParser.MAX_PROCESSES

	describe "with a processes limit", ->
		beforeEach ->
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the processes limit", ->
			@data.processes.should.equal @validRequest.compile.options.processes

	describe "without a memory limit specified", ->
		beforeEach ->
			delete @validRequest.compile.options.memory
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the memory limit to MAX_MEMORY", ->
			@data.memory.should.equal @RequestParser.MAX_MEMORY

	describe "with a memory limit larger than the maximum", ->
		beforeEach ->
			@validRequest.compile.options.memory = @RequestParser.MAX_MEMORY + 1
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the memory limit to MAX_MEMORY", ->
			@data.memory.should.equal @RequestParser.MAX_MEMORY

	describe "with a memory limit", ->
		beforeEach ->
			@RequestParser.parse @validRequest, (error, @data) =>

		it "should set the memory limit", ->
			@data.memory.should.equal @validRequest.compile.options.memory
	
	describe "with a resource without a path", ->
		beforeEach ->
			delete @validResource.path
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse @validRequest, @callback

		it "should return an error", ->
			@callback.calledWith(new Error "all resources should have a path attribute")
				.should.equal true

	describe "with a resource with a path", ->
		beforeEach ->
			@validResource.path = @path = "test.tex"
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse @validRequest, @callback
			@data = @callback.args[0][1]

		it "should return the path in the parsed response", ->
			@data.resources[0].path.should.equal @path

	describe "with a resource with a malformed modified date", ->
		beforeEach ->
			@validResource.modified = "not-a-date"
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse @validRequest, @callback

		it "should return an error", ->
			@callback
				.calledWith(
					new Error("resource modified date could not be understood: #{@validResource.modified}")
				)
				.should.equal true

	describe "with a resource with a valid date", ->
		beforeEach ->
			@date = "12:00 01/02/03"
			@validResource.modified = @date
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse @validRequest, @callback
			@data = @callback.args[0][1]

		it "should return the date as a Javascript Date object", ->
			(@data.resources[0].modified instanceof Date).should.equal true
			@data.resources[0].modified.getTime().should.equal Date.parse(@date)

	describe "with a resource without either a content or URL attribute", ->
		beforeEach ->
			delete @validResource.url
			delete @validResource.content
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse @validRequest, @callback

		it "should return an error", ->
			@callback.calledWith(new Error "all resources should have either a url or content attribute")
				.should.equal true

	describe "with a resource where the content is not a string", ->
		beforeEach ->
			@validResource.content = []
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse (@validRequest), @callback

		it "should return an error", ->
			@callback.calledWith(new Error "content attribute should be a string")
				.should.equal true

	describe "with a resource where the url is not a string", ->
		beforeEach ->
			@validResource.url = []
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse (@validRequest), @callback

		it "should return an error", ->
			@callback.calledWith(new Error "url attribute should be a string")
				.should.equal true

	describe "with a resource with a url", ->
		beforeEach ->
			@validResource.url = @url = "www.example.com"
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse (@validRequest), @callback
			@data = @callback.args[0][1]

		it "should return the url in the parsed response", ->
			@data.resources[0].url.should.equal @url
		
	describe "with a resource with a content attribute", ->
		beforeEach ->
			@validResource.content = @content = "Hello world"
			@validRequest.compile.resources.push @validResource
			@RequestParser.parse (@validRequest), @callback
			@data = @callback.args[0][1]

		it "should return the content in the parsed response", ->
			@data.resources[0].content.should.equal @content
		
	describe "without a root resource path", ->
		beforeEach ->
			delete @validRequest.compile.rootResourcePath
			@RequestParser.parse (@validRequest), @callback
			@data = @callback.args[0][1]

		it "should set the root resource path to 'main.tex' by default", ->
			@data.rootResourcePath.should.equal "main.tex"

	describe "with a root resource path", ->
		beforeEach ->
			@validRequest.compile.rootResourcePath = @path = "test.tex"
			@RequestParser.parse (@validRequest), @callback
			@data = @callback.args[0][1]

		it "should return the root resource path in the parsed response", ->
			@data.rootResourcePath.should.equal @path

	describe "with a root resource path that is not a string", ->
		beforeEach ->
			@validRequest.compile.rootResourcePath = []
			@RequestParser.parse (@validRequest), @callback

		it "should return an error", ->
			@callback.calledWith(new Error "rootResourcePath attribute should be a string")
				.should.equal true


		

