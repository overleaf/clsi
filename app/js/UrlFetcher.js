/* eslint-disable
    handle-callback-err,
    no-return-assign,
    no-unused-vars,
    node/no-deprecated-api,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const request = require('requestretry').defaults({ jar: false })
const fs = require('fs')
const logger = require('logger-sharelatex')
const settings = require('settings-sharelatex')
const URL = require('url')

const oneMinute = 60 * 1000

module.exports = UrlFetcher = {
  pipeUrlToFile(url, filePath, _callback) {
    if (_callback == null) {
      _callback = function(error) {}
    }
    const callbackOnce = function(error) {
      if (timeoutHandler != null) {
        clearTimeout(timeoutHandler)
      }
      _callback(error)
      return (_callback = function() {})
    }

    if (settings.filestoreDomainOveride != null) {
      const p = URL.parse(url).path
      url = `${settings.filestoreDomainOveride}${p}`
    }
    var timeoutHandler = setTimeout(
      function() {
        timeoutHandler = null
        logger.error({ url, filePath }, 'Timed out downloading file to cache')
        return callbackOnce(
          new Error(`Timed out downloading file to cache ${url}`)
        )
      },
      // FIXME: maybe need to close fileStream here
      3 * oneMinute
    )

    logger.log({ url, filePath }, 'started downloading url to cache')
    const urlStream = request.get({
      url,
      timeout: oneMinute,
      retryDelay: 1000,
      maxAttempts: 3
    })
    urlStream.pause() // stop data flowing until we are ready

    // attach handlers before setting up pipes
    urlStream.on('error', function(error) {
      logger.error({ err: error, url, filePath }, 'error downloading url')
      return callbackOnce(
        error || new Error(`Something went wrong downloading the URL ${url}`)
      )
    })

    urlStream.on('end', () =>
      logger.log({ url, filePath }, 'finished downloading file into cache')
    )

    return urlStream.on('response', function(res) {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        const fileStream = fs.createWriteStream(filePath)

        // attach handlers before setting up pipes
        fileStream.on('error', function(error) {
          logger.error(
            { err: error, url, filePath },
            'error writing file into cache'
          )
          return fs.unlink(filePath, function(err) {
            if (err != null) {
              logger.err({ err, filePath }, 'error deleting file from cache')
            }
            return callbackOnce(error)
          })
        })

        fileStream.on('finish', function() {
          logger.log({ url, filePath }, 'finished writing file into cache')
          return callbackOnce()
        })

        fileStream.on('pipe', () =>
          logger.log({ url, filePath }, 'piping into filestream')
        )

        urlStream.pipe(fileStream)
        return urlStream.resume() // now we are ready to handle the data
      } else {
        logger.error(
          { statusCode: res.statusCode, url, filePath },
          'unexpected status code downloading url to cache'
        )
        // https://nodejs.org/api/http.html#http_class_http_clientrequest
        // If you add a 'response' event handler, then you must consume
        // the data from the response object, either by calling
        // response.read() whenever there is a 'readable' event, or by
        // adding a 'data' handler, or by calling the .resume()
        // method. Until the data is consumed, the 'end' event will not
        // fire. Also, until the data is read it will consume memory
        // that can eventually lead to a 'process out of memory' error.
        urlStream.resume() // discard the data
        return callbackOnce(
          new Error(
            `URL returned non-success status code: ${res.statusCode} ${url}`
          )
        )
      }
    })
  }
}
