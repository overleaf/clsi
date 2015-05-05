chai = require("chai")
chai.should() unless Object.prototype.should?
expect = chai.expect
request = require "request"
Settings = require "settings-sharelatex"

buildUrl = (path) -> "http://#{Settings.internal.clsi.host}:#{Settings.internal.clsi.port}/#{path}"

describe "Running a compile", ->
	before (done) ->
		request.post {
			url: buildUrl("project/smoketest/compile")
			json:
				compile:
					options:
						compiler: "python"
					rootResourcePath: "main.py"
					resources: [
						path: "main.py"
						content: """
							print 'hello world'
						"""
					]
		}, (@error, @response, @body) =>
			done()

	it "should return the output", ->
		@body.compile.output.stdout.should.equal "hello world\n"
