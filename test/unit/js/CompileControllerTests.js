/* eslint-disable
    no-return-assign,
    no-unused-vars,
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
const modulePath = require('path').join(
  __dirname,
  '../../../app/js/CompileController'
)
const tk = require('timekeeper')

function tryImageNameValidation(method, imageNameField) {
  describe('when allowedImages is set', function () {
    beforeEach(function () {
      this.Settings.clsi = { docker: {} }
      this.Settings.clsi.docker.allowedImages = [
        'repo/image:tag1',
        'repo/image:tag2'
      ]
      this.res.send = sinon.stub()
      this.res.status = sinon.stub().returns({ send: this.res.send })

      this.CompileManager[method].reset()
    })

    describe('with an invalid image', function () {
      beforeEach(function () {
        this.req.query[imageNameField] = 'something/evil:1337'
        this.CompileController[method](this.req, this.res, this.next)
      })
      it('should return a 400', function () {
        expect(this.res.status.calledWith(400)).to.equal(true)
      })
      it('should not run the query', function () {
        expect(this.CompileManager[method].called).to.equal(false)
      })
    })

    describe('with a valid image', function () {
      beforeEach(function () {
        this.req.query[imageNameField] = 'repo/image:tag1'
        this.CompileController[method](this.req, this.res, this.next)
      })
      it('should not return a 400', function () {
        expect(this.res.status.calledWith(400)).to.equal(false)
      })
      it('should run the query', function () {
        expect(this.CompileManager[method].called).to.equal(true)
      })
    })
  })
}

describe('CompileController', function () {
  beforeEach(function () {
    this.CompileController = SandboxedModule.require(modulePath, {
      requires: {
        './CompileManager': (this.CompileManager = {}),
        './RequestParser': (this.RequestParser = {}),
        'settings-sharelatex': (this.Settings = {
          apis: {
            clsi: {
              url: 'http://clsi.example.com'
            }
          }
        }),
        './ProjectPersistenceManager': (this.ProjectPersistenceManager = {})
      }
    })
    this.Settings.externalUrl = 'http://www.example.com'
    this.req = {}
    this.res = {}
    return (this.next = sinon.stub())
  })

  describe('compile', function () {
    beforeEach(function () {
      this.req.body = {
        compile: 'mock-body'
      }
      this.req.params = { project_id: (this.project_id = 'project-id-123') }
      this.request = {
        compile: 'mock-parsed-request'
      }
      this.request_with_project_id = {
        compile: this.request.compile,
        project_id: this.project_id
      }
      this.output_files = [
        {
          path: 'output.pdf',
          type: 'pdf',
          build: 1234
        },
        {
          path: 'output.log',
          type: 'log',
          build: 1234
        }
      ]
      this.RequestParser.parse = sinon
        .stub()
        .callsArgWith(1, null, this.request)
      this.ProjectPersistenceManager.markProjectAsJustAccessed = sinon
        .stub()
        .callsArg(1)
      this.res.status = sinon.stub().returnsThis()
      return (this.res.send = sinon.stub())
    })

    describe('successfully', function () {
      beforeEach(function () {
        this.CompileManager.doCompileWithLock = sinon
          .stub()
          .callsArgWith(1, null, this.output_files)
        return this.CompileController.compile(this.req, this.res)
      })

      it('should parse the request', function () {
        return this.RequestParser.parse
          .calledWith(this.req.body)
          .should.equal(true)
      })

      it('should run the compile for the specified project', function () {
        return this.CompileManager.doCompileWithLock
          .calledWith(this.request_with_project_id)
          .should.equal(true)
      })

      it('should mark the project as accessed', function () {
        return this.ProjectPersistenceManager.markProjectAsJustAccessed
          .calledWith(this.project_id)
          .should.equal(true)
      })

      return it('should return the JSON response', function () {
        this.res.status.calledWith(200).should.equal(true)
        return this.res.send
          .calledWith({
            compile: {
              status: 'success',
              error: null,
              outputFiles: this.output_files.map((file) => {
                return {
                  url: `${this.Settings.apis.clsi.url}/project/${this.project_id}/build/${file.build}/output/${file.path}`,
                  path: file.path,
                  type: file.type,
                  build: file.build,
                  // gets dropped by JSON.stringify
                  contentId: undefined
                }
              })
            }
          })
          .should.equal(true)
      })
    })

    describe('with user provided fake_output.pdf', function () {
      beforeEach(function () {
        this.output_files = [
          {
            path: 'fake_output.pdf',
            type: 'pdf',
            build: 1234
          },
          {
            path: 'output.log',
            type: 'log',
            build: 1234
          }
        ]
        this.CompileManager.doCompileWithLock = sinon
          .stub()
          .callsArgWith(1, null, this.output_files)
        this.CompileController.compile(this.req, this.res)
      })

      it('should return the JSON response with status failure', function () {
        this.res.status.calledWith(200).should.equal(true)
        this.res.send
          .calledWith({
            compile: {
              status: 'failure',
              error: null,
              outputFiles: this.output_files.map((file) => {
                return {
                  url: `${this.Settings.apis.clsi.url}/project/${this.project_id}/build/${file.build}/output/${file.path}`,
                  path: file.path,
                  type: file.type,
                  build: file.build,
                  // gets dropped by JSON.stringify
                  contentId: undefined
                }
              })
            }
          })
          .should.equal(true)
      })
    })

    describe('with an error', function () {
      beforeEach(function () {
        this.CompileManager.doCompileWithLock = sinon
          .stub()
          .callsArgWith(1, new Error((this.message = 'error message')), null)
        return this.CompileController.compile(this.req, this.res)
      })

      return it('should return the JSON response with the error', function () {
        this.res.status.calledWith(500).should.equal(true)
        return this.res.send
          .calledWith({
            compile: {
              status: 'error',
              error: this.message,
              outputFiles: []
            }
          })
          .should.equal(true)
      })
    })

    describe('when the request times out', function () {
      beforeEach(function () {
        this.error = new Error((this.message = 'container timed out'))
        this.error.timedout = true
        this.CompileManager.doCompileWithLock = sinon
          .stub()
          .callsArgWith(1, this.error, null)
        return this.CompileController.compile(this.req, this.res)
      })

      return it('should return the JSON response with the timeout status', function () {
        this.res.status.calledWith(200).should.equal(true)
        return this.res.send
          .calledWith({
            compile: {
              status: 'timedout',
              error: this.message,
              outputFiles: []
            }
          })
          .should.equal(true)
      })
    })

    return describe('when the request returns no output files', function () {
      beforeEach(function () {
        this.CompileManager.doCompileWithLock = sinon
          .stub()
          .callsArgWith(1, null, [])
        return this.CompileController.compile(this.req, this.res)
      })

      return it('should return the JSON response with the failure status', function () {
        this.res.status.calledWith(200).should.equal(true)
        return this.res.send
          .calledWith({
            compile: {
              error: null,
              status: 'failure',
              outputFiles: []
            }
          })
          .should.equal(true)
      })
    })
  })

  describe('syncFromCode', function () {
    beforeEach(function () {
      this.file = 'main.tex'
      this.line = 42
      this.column = 5
      this.project_id = 'mock-project-id'
      this.req.params = { project_id: this.project_id }
      this.req.query = {
        file: this.file,
        line: this.line.toString(),
        column: this.column.toString()
      }
      this.res.json = sinon.stub()

      this.CompileManager.syncFromCode = sinon
        .stub()
        .yields(null, (this.pdfPositions = ['mock-positions']))
      return this.CompileController.syncFromCode(this.req, this.res, this.next)
    })

    it('should find the corresponding location in the PDF', function () {
      return this.CompileManager.syncFromCode
        .calledWith(
          this.project_id,
          undefined,
          this.file,
          this.line,
          this.column
        )
        .should.equal(true)
    })

    it('should return the positions', function () {
      return this.res.json
        .calledWith({
          pdf: this.pdfPositions
        })
        .should.equal(true)
    })

    tryImageNameValidation('syncFromCode', 'imageName')
  })

  describe('syncFromPdf', function () {
    beforeEach(function () {
      this.page = 5
      this.h = 100.23
      this.v = 45.67
      this.project_id = 'mock-project-id'
      this.req.params = { project_id: this.project_id }
      this.req.query = {
        page: this.page.toString(),
        h: this.h.toString(),
        v: this.v.toString()
      }
      this.res.json = sinon.stub()

      this.CompileManager.syncFromPdf = sinon
        .stub()
        .yields(null, (this.codePositions = ['mock-positions']))
      return this.CompileController.syncFromPdf(this.req, this.res, this.next)
    })

    it('should find the corresponding location in the code', function () {
      return this.CompileManager.syncFromPdf
        .calledWith(this.project_id, undefined, this.page, this.h, this.v)
        .should.equal(true)
    })

    it('should return the positions', function () {
      return this.res.json
        .calledWith({
          code: this.codePositions
        })
        .should.equal(true)
    })

    tryImageNameValidation('syncFromPdf', 'imageName')
  })

  return describe('wordcount', function () {
    beforeEach(function () {
      this.file = 'main.tex'
      this.project_id = 'mock-project-id'
      this.req.params = { project_id: this.project_id }
      this.req.query = {
        file: this.file,
        image: (this.image = 'example.com/image')
      }
      this.res.json = sinon.stub()

      this.CompileManager.wordcount = sinon
        .stub()
        .callsArgWith(4, null, (this.texcount = ['mock-texcount']))
    })

    it('should return the word count of a file', function () {
      this.CompileController.wordcount(this.req, this.res, this.next)
      return this.CompileManager.wordcount
        .calledWith(this.project_id, undefined, this.file, this.image)
        .should.equal(true)
    })

    it('should return the texcount info', function () {
      this.CompileController.wordcount(this.req, this.res, this.next)
      return this.res.json
        .calledWith({
          texcount: this.texcount
        })
        .should.equal(true)
    })

    tryImageNameValidation('wordcount', 'image')
  })
})
