request = require "request"
logger = require "logger-sharelatex"
settings = require "settings-sharelatex"

module.exports = RealTimeApiManager =
	BUFFER_DELAY: 200
	
	BUFFERED_MESSAGES: {}
	
	bufferMessageForSending: (project_id, message) ->
		if RealTimeApiManager.BUFFERED_MESSAGES[project_id]?
			# We already have a send scheduled, so just add more messages to it
			RealTimeApiManager._concatMessage project_id, message
		else
			RealTimeApiManager.BUFFERED_MESSAGES[project_id] = [message]
			setTimeout () ->
				RealTimeApiManager._sendAndClearBufferedMessages project_id
			, RealTimeApiManager.BUFFER_DELAY
			
	_concatMessage: (project_id, message) ->
		allMessages = RealTimeApiManager.BUFFERED_MESSAGES[project_id]
		lastMessage = allMessages[allMessages.length - 1]
		if lastMessage.msg_type == "stream" and message.msg_type == "stream" and lastMessage.content.name == message.content.name
			# Don't add a new message if it's the same stream name (stdout or stderr), just concat to old
			lastMessage.content.text += message.content.text
		else
			allMessages.push message
	
	_sendAndClearBufferedMessages: (project_id) ->
		RealTimeApiManager.sendMessage project_id, RealTimeApiManager.BUFFERED_MESSAGES[project_id], (err) ->
			if err?
				logger.err {err, project_id, message}, "error sending message to real-time API"
		delete RealTimeApiManager.BUFFERED_MESSAGES[project_id]

	sendMessage: (project_id, message, callback = (error) ->) ->
		logger.log {project_id, message}, "sending message to client"
		request {
			url: "#{settings.apis.realtime.url}/project/#{project_id}/message/clsiOutput"
			method: "POST"
			json: message
			auth:
				user: settings.apis.realtime.user
				pass: settings.apis.realtime.pass
				sendImmediately: true
		}, (error, response, body) ->
			return callback(error) if error?
			if 200 <= response.statusCode < 300
				logger.log {project_id, statusCode: response.statusCode}, "sent message to client"
				return callback()
			else
				err = new Error("real-time api returned non-zero status code: #{response.statusCode}")
				logger.err {err, project_id, statusCode: response.statusCode}, "real-time api returned non-zero status code"
				return callback err
