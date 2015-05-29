request = require "request"
logger = require "logger-sharelatex"
settings = require "settings-sharelatex"

module.exports = RealTimeApiManager =
	BUFFER_DELAY: 200
	
	BUFFERED_MESSAGES: {}
	
	MESSAGE_LENGTH_LIMIT: 64 * 1024 * 1024 # 64kb
	
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
		if lastMessage.header?.msg_type == "stream" and message.header?.msg_type == "stream" and lastMessage.content.name == message.content.name
			# Don't add a new message if it's the same stream name (stdout or stderr), just concat to old
			lastMessage.content.text += message.content.text
		else
			allMessages.push message
			
	_trimLongMessages: (messages) ->
		trim = (content) ->
			if content.length > RealTimeApiManager.MESSAGE_LENGTH_LIMIT
				return content.slice(0, RealTimeApiManager.MESSAGE_LENGTH_LIMIT) + "..."
			else
				return content
		for message in messages
			if message.content.text?
				message.content.text = trim(message.content.text)
			if message.header?.msg_type == "execute_result"
				delete message.content.data?["text/markdown"]
				delete message.content.data?["text/html"]
				delete message.content.data?["text/latex"]
				if message.content.data?["text/plain"]?
					message.content.data["text/plain"] = trim(message.content.data["text/plain"])
		return messages
	
	_sendAndClearBufferedMessages: (project_id) ->
		messages = RealTimeApiManager.BUFFERED_MESSAGES[project_id]
		messages = RealTimeApiManager._trimLongMessages messages
		RealTimeApiManager.sendMessage project_id, messages, (err) ->
			if err?
				logger.err {err, project_id}, "error sending message to real-time API"
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
