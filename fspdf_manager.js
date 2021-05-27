const { LocalPdfManager } = require('pdfjs-dist/lib/core/pdf_manager');
const { PDFDocument } = require('pdfjs-dist/lib/core/document');
const { FileStream } = require('./filestream.js')
const { MissingDataException } = require('pdfjs-dist/lib/core/core_utils')

class FileSystemPdfManager extends LocalPdfManager {
    constructor(docId, options, password) {
        super(docId, Buffer.from("dummy"));
        this.stream = new FileStream(options.fh, 0, options.size);
        this.pdfDocument = new PDFDocument(this, this.stream);
    }

    async ensure(obj, prop, args) {
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
        return this.stream.requestRange(begin, end)
    }

    requestLoadedStream() { 
        console.log("requestLoadedStream")
    }

    onLoadedStream() {
        console.log("onLoadedStream")
    }

    terminate(reason) { }
}

module.exports = {
    FileSystemPdfManager: FileSystemPdfManager
}