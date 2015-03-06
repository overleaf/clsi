request = require "request"
logger = require "logger-sharelatex"
settings = require "settings-sharelatex"

module.exports = RealTimeApiManager =
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