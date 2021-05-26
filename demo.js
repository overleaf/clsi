const { FSPdfManager } = require('./fspdf_manager')
const { LocalPdfManager } = require('pdfjs-dist/lib/core/pdf_manager')
const fs = require('fs')

const pdfPath = "test.pdf" //process.argv[2]
// const arrayBuffer = fs.readFileSync(pdfPath)
// console.log("array buffer", arrayBuffer.length)
const fd = fs.openSync(pdfPath)
const stats = fs.fstatSync(fd)
const size = stats.size

const pdfManager = new FSPdfManager(1, { fd, size }, '', {}, '')
pdfManager.ensureDoc('checkHeader', []).then(() => {
  return pdfManager.ensureDoc('parseStartXRef', [])
}).then(() => {
  console.log(pdfManager.pdfDocument)
  return pdfManager.ensureDoc('parse')
}).then(() => {
  //console.log("Xref entries", pdfManager.pdfDocument.catalog.xref.entries)
})

