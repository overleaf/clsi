Client = require "./helpers/Client"
request = require "request"
require("chai").should()
fs = require "fs"
ChildProcess = require "child_process"

fixturePath = (path) -> __dirname + "/../fixtures/" + path

try
	fs.mkdirSync(fixturePath("tmp"))
catch e

convertToPng = (pdfPath, pngPath, callback = (error) ->) ->
	convert = ChildProcess.exec "convert #{fixturePath(pdfPath)} #{fixturePath(pngPath)}"
	convert.on "exit", () ->
		callback()

compare = (originalPath, generatedPath, callback = (error, same) ->) ->
	diff_file = "#{fixturePath(generatedPath)}-diff.png"
	proc = ChildProcess.exec "compare -metric mae #{fixturePath(originalPath)} #{fixturePath(generatedPath)} #{diff_file}"
	stderr = ""
	proc.stderr.on "data", (chunk) -> stderr += chunk
	proc.on "exit", () ->
		if stderr.trim() == "0 (0)"
			fs.unlink diff_file # remove output diff if test matches expected image
			callback null, true
		else
			console.log "compare result", stderr
			callback null, false

checkPdfInfo = (pdfPath, callback = (error, output) ->) ->
	proc = ChildProcess.exec "pdfinfo #{fixturePath(pdfPath)}"
	stdout = ""
	proc.stdout.on "data", (chunk) -> stdout += chunk
	proc.stderr.on "data", (chunk) -> console.log "STDERR", chunk.toString()
	proc.on "exit", () ->
		if stdout.match(/Optimized:\s+yes/)
			callback null, true
		else
			console.log "pdfinfo result", stdout
			callback null, false

compareMultiplePages = (project_id, callback = (error) ->) ->
	compareNext = (page_no, callback) ->
		path = "tmp/#{project_id}-source-#{page_no}.png"
		fs.stat fixturePath(path), (error, stat) ->
			if error?
				callback()
			else
				compare  "tmp/#{project_id}-source-#{page_no}.png", "tmp/#{project_id}-generated-#{page_no}.png", (error, same) =>
					throw error if error?
					same.should.equal true
					compareNext page_no + 1, callback
	compareNext 0, callback

comparePdf = (project_id, example_dir, callback = (error) ->) ->
	convertToPng "tmp/#{project_id}.pdf", "tmp/#{project_id}-generated.png", (error) =>
		throw error if error?
		convertToPng "examples/#{example_dir}/output.pdf", "tmp/#{project_id}-source.png", (error) =>
			throw error if error?
			fs.stat fixturePath("tmp/#{project_id}-source-0.png"), (error, stat) =>
				if error?
					compare  "tmp/#{project_id}-source.png", "tmp/#{project_id}-generated.png", (error, same) =>
						throw error if error?
						same.should.equal true
						callback()
				else
					compareMultiplePages project_id, (error) ->
						throw error if error?
						callback()

downloadAndComparePdf = (project_id, example_dir, url, callback = (error) ->) ->
	writeStream = fs.createWriteStream(fixturePath("tmp/#{project_id}.pdf"))
	request.get(url).pipe(writeStream)
	writeStream.on "close", () =>
		checkPdfInfo "tmp/#{project_id}.pdf", (error, optimised) =>
			throw error if error?
			optimised.should.equal true
			comparePdf project_id, example_dir, callback

Client.runServer(4242, fixturePath("examples"))

describe "Example Documents", ->
	before (done) ->
		ChildProcess.exec("rm test/acceptance/fixtures/tmp/*").on "exit", () -> done()

	for example_dir in fs.readdirSync fixturePath("examples")
		do (example_dir) ->
			describe example_dir, ->
				before ->
					@project_id = Client.randomId() + "_" + example_dir

				it "should generate the correct pdf", (done) ->
					Client.compileDirectory @project_id, fixturePath("examples"), example_dir, 4242, (error, res, body) =>
						if error || body?.compile?.status is "failure"
							console.log "DEBUG: error", error, "body", JSON.stringify(body)
						pdf = Client.getOutputFile body, "pdf"
						downloadAndComparePdf(@project_id, example_dir, pdf.url, done)

				it "should generate the correct pdf on the second run as well", (done) ->
					Client.compileDirectory @project_id, fixturePath("examples"), example_dir, 4242, (error, res, body) =>
						if error || body?.compile?.status is "failure"
							console.log "DEBUG: error", error, "body", JSON.stringify(body)
						pdf = Client.getOutputFile body, "pdf"
						downloadAndComparePdf(@project_id, example_dir, pdf.url, done)


