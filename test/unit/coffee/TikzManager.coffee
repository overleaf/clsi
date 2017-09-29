SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../app/js/TikzManager'

describe 'TikzManager', ->
	beforeEach ->
		@TikzManager = SandboxedModule.require modulePath, requires:
			"./ResourceWriter": @ResourceWriter = {}
			"./SafeReader": @SafeReader = {}
			"fs": @fs = {}
			"logger-sharelatex": @logger = {log: () ->}
		@callback = sinon.stub()

	describe "createTikzFileIfRequired", ->
		beforeEach ->
				@compileDir = "compile-dir"
				@rootResourcePath = "main.tex"
				@resources = [{path:"main.tex", content:"hello"}]
				@TikzManager.injectOutputFile = sinon.stub().callsArg(2)

		describe "when the output file is needed", ->
			beforeEach ->
				@TikzManager.needsOutputFile = sinon.stub().returns true
				@TikzManager.createTikzFileIfRequired @compileDir, @rootResourcePath, @resources, @callback

			it "should check if the output file is needed", ->
				@TikzManager.needsOutputFile
				.called.should.equal true

			it "should  inject the output file", ->
				@TikzManager.injectOutputFile
				.calledWith(@compileDir, @rootResourcePath, @callback)
				.should.equal true

			it "should call the callback", ->
				@callback.called
				.should.equal true

		describe "when the output file is not needed", ->
			beforeEach ->
				@TikzManager.needsOutputFile = sinon.stub().returns false
				@TikzManager.createTikzFileIfRequired @compileDir, @rootResourcePath, @resources, @callback

			it "should check if the output file is needed", ->
				@TikzManager.needsOutputFile
				.called.should.equal true

			it "should not inject the output file", ->
				@TikzManager.injectOutputFile
				.called
				.should.equal false

			it "should call the callback", ->
				@callback.called
				.should.equal true

		describe "when the output file is missing", ->
			beforeEach ->
				@resources = [{path:"main.tex"}]
				@ResourceWriter.checkPath = sinon.stub()
					.withArgs(@compileDir, @rootResourcePath)
					.callsArgWith(2, null, "#{@compileDir}/#{@rootResourcePath}")

			describe "and the file on disk does not contain \\tikzexternalize", ->
				beforeEach ->
					@SafeReader.readFile = sinon.stub()
						.withArgs("#{@compileDir}/#{@rootResourcePath}")
						.callsArgWith(3, null, "hello")
					@TikzManager.createTikzFileIfRequired @compileDir, @rootResourcePath, @resources, @callback

				it "should look at the file on disk", ->
					@SafeReader.readFile
					.calledWith("#{@compileDir}/#{@rootResourcePath}")
					.should.equal true

				it "should not inject the output file", ->
					@TikzManager.injectOutputFile
					.called
					.should.equal false

				it "should call the callback", ->
					@callback.called
					.should.equal true

			describe "and the file on disk does contain \\tikzexternalize", ->
				beforeEach ->
					@SafeReader.readFile = sinon.stub()
						.withArgs("#{@compileDir}/#{@rootResourcePath}")
						.callsArgWith(3, null, "hello \\tikzexternalize")
					@TikzManager.createTikzFileIfRequired @compileDir, @rootResourcePath, @resources, @callback

				it "should look at the file on disk", ->
					@SafeReader.readFile
					.calledWith("#{@compileDir}/#{@rootResourcePath}")
					.should.equal true

				it "should inject the output file", ->
					@TikzManager.injectOutputFile
					.called
					.should.equal true

				it "should call the callback", ->
					@callback.called
					.should.equal true

	describe "needsOutputFile", ->
		it "should return true if there is a \\tikzexternalize", ->
			@TikzManager.needsOutputFile("main.tex", [
				{ path: 'foo.tex' },
				{ path: 'main.tex', content:'foo \\usepackage{tikz} \\tikzexternalize' }
			]).should.equal true

		it "should return false if there is no \\tikzexternalize", ->
			@TikzManager.needsOutputFile("main.tex", [
				{ path: 'foo.tex' },
				{ path: 'main.tex', content:'foo \\usepackage{tikz}' }
			]).should.equal false

		it "should return false if there is already an output.tex file", ->
			@TikzManager.needsOutputFile("main.tex", [
				{ path: 'foo.tex' },
				{ path: 'main.tex', content:'foo \\usepackage{tikz} \\tikzexternalize' },
				{ path: 'output.tex' }
			]).should.equal false

		it "should return 'missing' if the file has no content (incremental compile)", ->
			@TikzManager.needsOutputFile("main.tex", [
				{ path: 'foo.tex' },
				{ path: 'main.tex' }
			]).should.equal "missing"

	describe "injectOutputFile", ->
		beforeEach ->
			@rootDir = "/mock"
			@filename = "filename.tex"
			@callback = sinon.stub()
			@content = '''
				\\documentclass{article}
				\\usepackage{tikz}
				\\tikzexternalize
				\\begin{document}
				Hello world
				\\end{document}
			'''
			@fs.readFile = sinon.stub().callsArgWith(2, null, @content)
			@fs.writeFile = sinon.stub().callsArg(3)
			@ResourceWriter.checkPath = sinon.stub().callsArgWith(2, null, "#{@rootDir}/#{@filename}")
			@TikzManager.injectOutputFile @rootDir, @filename, @callback

		it "sould check the path", ->
			@ResourceWriter.checkPath.calledWith(@rootDir, @filename)
			.should.equal true

		it "should read the file", ->
			@fs.readFile
				.calledWith("#{@rootDir}/#{@filename}", "utf8")
				.should.equal true

		it "should write out the same file as output.tex", ->
			@fs.writeFile
				.calledWith("#{@rootDir}/output.tex", @content, {flag: 'wx'})
				.should.equal true

		it "should call the callback", ->
			@callback.called.should.equal true
