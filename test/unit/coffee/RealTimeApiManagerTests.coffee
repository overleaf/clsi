SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
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
