SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
expect = require("chai").expect
modulePath = require('path').join __dirname, '../../../app/js/RealTimeApiManager'

describe "RealTimeApiManager", ->
	beforeEach ->
		@RealTimeApiManager = SandboxedModule.require modulePath, requires:
			"request": @request = sinon.stub()
			"logger-sharelatex": @logger = {log: sinon.stub(), err: sinon.stub()}
			"settings-sharelatex": @settings = 
				apis:
					realtime:
						url: "realtime.example.com"
						user: "mock-user"
						pass: "mock-pass"
			
		@callback  = sinon.stub()
		@project_id = "project-id-123"
		@message = {"mock": "message"}
		
	describe "bufferMessageForSending", ->
		beforeEach ->
			@RealTimeApiManager.BUFFER_DELAY = 10
			@RealTimeApiManager.sendMessage = sinon.stub().callsArg(2)
			
			@messages = [
				{ msg_type: "stream", content: { name: "stdout", text: "Hello" } },
				{ msg_type: "stream", content: { name: "stderr", text: "World" } }
			]

		describe "with multiple messages in quick succession", ->
			beforeEach (done) ->
				@RealTimeApiManager.bufferMessageForSending @project_id, @messages[0]
				@RealTimeApiManager.bufferMessageForSending @project_id, @messages[1]
				
				setTimeout () ->
					done()
				, @RealTimeApiManager.BUFFER_DELAY * 2
			
			it "should send the messages in one batch to the real time service", ->
				@RealTimeApiManager.sendMessage
					.calledWith(@project_id, @messages)
					.should.equal true
		
		describe "with multiple messages with a delay between", ->
			beforeEach (done) ->
				@RealTimeApiManager.bufferMessageForSending @project_id, @messages[0]
				
				setTimeout () =>
					@RealTimeApiManager.bufferMessageForSending @project_id, @messages[1]
				, @RealTimeApiManager.BUFFER_DELAY * 2
				
				setTimeout () ->
					done()
				, @RealTimeApiManager.BUFFER_DELAY * 4
			
			it "should send the messages in two batches to the real time service", ->
				@RealTimeApiManager.sendMessage
					.calledWith(@project_id, [@messages[0]])
					.should.equal true
				@RealTimeApiManager.sendMessage
					.calledWith(@project_id, [@messages[1]])
					.should.equal true
		
		describe "with multiple messages on the same stream in quick succession", ->
			beforeEach (done) ->
				@RealTimeApiManager.bufferMessageForSending @project_id, {
					msg_type: "stream", content: { name: "stdout", text: "Hello" } 
				}
				@RealTimeApiManager.bufferMessageForSending @project_id, {
					msg_type: "stream", content: { name: "stdout", text: " world" } 
				}
				@RealTimeApiManager.bufferMessageForSending @project_id, {
					msg_type: "stream", content: { name: "stderr", text: "foo" } 
				}
				@RealTimeApiManager.bufferMessageForSending @project_id, {
					msg_type: "stream", content: { name: "stderr", text: "bar" } 
				}
				@RealTimeApiManager.bufferMessageForSending @project_id, {
					msg_type: "stream", content: { name: "stdout", text: "baz" } 
				}
				
				setTimeout () ->
					done()
				, @RealTimeApiManager.BUFFER_DELAY * 2
			
			it "should concat adjacent messages on the same stream", ->
				messages = @RealTimeApiManager.sendMessage.args[0][1]
				expect(messages).to.deep.equal [
					{ msg_type: "stream", content: { name: "stdout", text: "Hello world" } }
					{ msg_type: "stream", content: { name: "stderr", text: "foobar" } }
					{ msg_type: "stream", content: { name: "stdout", text: "baz" } }
				]
				
	describe "sendMessage", ->
		describe "with success", ->
			beforeEach ->
				@request.callsArgWith(1, null, { statusCode: 200 })
				@RealTimeApiManager.sendMessage @project_id, @message, @callback
				
			it "should post the message to the real-time API", ->
				@request
					.calledWith({
						method: "POST",
						url: "#{@settings.apis.realtime.url}/project/#{@project_id}/message/clsiOutput"
						json: @message
						auth:
							user: @settings.apis.realtime.user
							pass: @settings.apis.realtime.pass
							sendImmediately: true
					})
					.should.equal true

			it "should call the callback", ->
				@callback.called.should.equal true

		describe "with error", ->
			beforeEach ->
				@request.callsArgWith(1, null, { statusCode: 500 })
				@RealTimeApiManager.sendMessage @project_id, @message, @callback

			it "should call the callback with an error", ->
				@callback
					.calledWith(new Error("real-time api returned non-zero success code: 500"))
					.should.equal true
