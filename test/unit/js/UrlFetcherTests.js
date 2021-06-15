/* eslint-disable
    no-return-assign,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const SandboxedModule = require('sandboxed-module')
const sinon = require('sinon')
const { expect } = require('chai')
const modulePath = require('path').join(__dirname, '../../../app/js/UrlFetcher')
const { EventEmitter } = require('events')

describe('UrlFetcher', function () {
  beforeEach(function () {
    this.callback = sinon.stub()
    this.url = 'https://www.example.com/file/here?query=string'
    return (this.UrlFetcher = SandboxedModule.require(modulePath, {
      requires: {
        request: {
          defaults: (this.defaults = sinon.stub().returns((this.request = {})))
        },
        fs: (this.fs = {
          rename: sinon.stub().yields(),
          unlink: sinon.stub().yields()
        }),
        'settings-sharelatex': (this.settings = {})
      }
    }))
  })
  describe('pipeUrlToFileWithRetry', function () {
    this.beforeEach(function () {
      this.UrlFetcher.pipeUrlToFile = sinon.stub()
    })

    it('should call pipeUrlToFile', function (done) {
      this.UrlFetcher.pipeUrlToFile.callsArgWith(2)
      this.UrlFetcher.pipeUrlToFileWithRetry(this.url, this.path, (err) => {
        expect(err).to.equal(undefined)
        this.UrlFetcher.pipeUrlToFile.called.should.equal(true)
        done()
      })
    })

    it('should call pipeUrlToFile multiple times on error', function (done) {
      const error = new Error("couldn't download file")
      this.UrlFetcher.pipeUrlToFile.callsArgWith(2, error)
      this.UrlFetcher.pipeUrlToFileWithRetry(this.url, this.path, (err) => {
        expect(err).to.equal(error)
        this.UrlFetcher.pipeUrlToFile.callCount.should.equal(3)
        done()
      })
    })

    it('should call pipeUrlToFile twice if only 1 error', function (done) {
      this.UrlFetcher.pipeUrlToFile.onCall(0).callsArgWith(2, 'error')
      this.UrlFetcher.pipeUrlToFile.onCall(1).callsArgWith(2)
      this.UrlFetcher.pipeUrlToFileWithRetry(this.url, this.path, (err) => {
        expect(err).to.equal(undefined)
        this.UrlFetcher.pipeUrlToFile.callCount.should.equal(2)
        done()
      })
    })
  })

  describe('pipeUrlToFile', function () {
    it('should turn off the cookie jar in request', function () {
      return this.defaults.calledWith({ jar: false }).should.equal(true)
    })

    describe('rewrite url domain if filestoreDomainOveride is set', function () {
      beforeEach(function () {
        this.path = '/path/to/file/on/disk'
        this.request.get = sinon
          .stub()
          .returns((this.urlStream = new EventEmitter()))
        this.urlStream.pipe = sinon.stub()
        this.urlStream.pause = sinon.stub()
        this.urlStream.resume = sinon.stub()
        this.fs.createWriteStream = sinon
          .stub()
          .returns((this.fileStream = new EventEmitter()))
        return (this.fs.unlink = (file, callback) => callback())
      })

      it('should use the normal domain when override not set', function (done) {
        this.UrlFetcher.pipeUrlToFile(this.url, this.path, () => {
          this.request.get.args[0][0].url.should.equal(this.url)
          return done()
        })
        this.res = { statusCode: 200 }
        this.urlStream.emit('response', this.res)
        this.urlStream.emit('end')
        return this.fileStream.emit('finish')
      })

      return it('should use override domain when filestoreDomainOveride is set', function (done) {
        this.settings.filestoreDomainOveride = '192.11.11.11'
        this.UrlFetcher.pipeUrlToFile(this.url, this.path, () => {
          this.request.get.args[0][0].url.should.equal(
            '192.11.11.11/file/here?query=string'
          )
          return done()
        })
        this.res = { statusCode: 200 }
        this.urlStream.emit('response', this.res)
        this.urlStream.emit('end')
        return this.fileStream.emit('finish')
      })
    })

    return describe('pipeUrlToFile', function () {
      beforeEach(function (done) {
        this.path = '/path/to/file/on/disk'
        this.request.get = sinon
          .stub()
          .returns((this.urlStream = new EventEmitter()))
        this.urlStream.pipe = sinon.stub()
        this.urlStream.pause = sinon.stub()
        this.urlStream.resume = sinon.stub()
        this.fs.createWriteStream = sinon
          .stub()
          .returns((this.fileStream = new EventEmitter()))
        this.fs.unlink = (file, callback) => callback()
        return done()
      })

      describe('successfully', function () {
        beforeEach(function (done) {
          this.UrlFetcher.pipeUrlToFile(this.url, this.path, () => {
            this.callback()
            return done()
          })
          this.res = { statusCode: 200 }
          this.urlStream.emit('response', this.res)
          this.urlStream.emit('end')
          return this.fileStream.emit('finish')
        })

        it('should request the URL', function () {
          return this.request.get
            .calledWith(sinon.match({ url: this.url }))
            .should.equal(true)
        })

        it('should open the atomic file for writing', function () {
          return this.fs.createWriteStream
            .calledWith(this.path + '~')
            .should.equal(true)
        })

        it('should move the atomic file to the target', function () {
          return this.fs.rename
            .calledWith(this.path + '~', this.path)
            .should.equal(true)
        })

        it('should pipe the URL to the file', function () {
          return this.urlStream.pipe
            .calledWith(this.fileStream)
            .should.equal(true)
        })

        return it('should call the callback', function () {
          return this.callback.called.should.equal(true)
        })
      })

      describe('with non success status code', function () {
        beforeEach(function (done) {
          this.UrlFetcher.pipeUrlToFile(this.url, this.path, (err) => {
            this.callback(err)
            return done()
          })
          this.res = { statusCode: 404 }
          this.urlStream.emit('response', this.res)
          return this.urlStream.emit('end')
        })

        it('should call the callback with an error', function () {
          this.callback.calledWith(sinon.match(Error)).should.equal(true)

          const message = this.callback.args[0][0].message
          expect(message).to.include(
            'URL returned non-success status code: 404'
          )
        })
      })

      return describe('with error', function () {
        beforeEach(function (done) {
          this.UrlFetcher.pipeUrlToFile(this.url, this.path, (err) => {
            this.callback(err)
            return done()
          })
          return this.urlStream.emit(
            'error',
            (this.error = new Error('something went wrong'))
          )
        })

        it('should call the callback with the error', function () {
          return this.callback.calledWith(this.error).should.equal(true)
        })

        return it('should only call the callback once, even if end is called', function () {
          this.urlStream.emit('end')
          return this.callback.calledOnce.should.equal(true)
        })
      })
    })
  })
})
