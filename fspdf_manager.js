const { LocalPdfManager } = require('pdfjs-dist/lib/core/pdf_manager');
const { PDFDocument } = require('pdfjs-dist/lib/core/document');
const { FSStream } = require('./fsstream.js')
const primitives = require('pdfjs-dist/lib/core/primitives');
const { MissingDataException } = require('pdfjs-dist/lib/core/core_utils')

class FSPdfManager extends LocalPdfManager {
    constructor(docId, options, password) {
        super(docId, Buffer.from("dummy"));
        this._docId = docId;
        this._password = password;
        // this._docBaseUrl = parseDocBaseUrl(docBaseUrl);
        // this.evaluatorOptions = evaluatorOptions;
        // this.enableXfa = enableXfa;
        const stream = new FSStream(options.fd, 0, options.size);
        this.pdfDocument = new PDFDocument(this, stream);
        this._loadedStreamPromise = new Promise(() => { });
    }

    async ensure(obj, prop, args) {
        console.log("ensure", prop, args)
        try {
            const value = obj[prop];
            if (typeof value === "function") {
                return value.apply(obj, args);
            }
            return value;
        } catch (ex) {
            if (!(ex instanceof MissingDataException)) {
                throw ex;
            }
            await this.requestRange(ex.begin, ex.end);
            return this.ensure(obj, prop, args);
        }
    }

    requestRange(begin, end) {
        console.log("requestRange", begin, end)
        return Promise.resolve();
    }

    requestLoadedStream() { }

    onLoadedStream() {
        return this._loadedStreamPromise;
    }

    terminate(reason) { }
}

module.exports = {
    FSPdfManager
}