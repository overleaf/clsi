const { FileSystemPdfManager } = require('./fspdf_manager')
const fs = require('fs')

const pdfPath = process.argv[2]

const fh = fs.promises.open(pdfPath)
fh.then(handle => {
  handle.stat().then(stats => {
    const pdfManager = new FileSystemPdfManager(1, { fh: handle, size: stats.size }, '', {}, '')
    pdfManager.ensureDoc('checkHeader', []).then(() => {
      return pdfManager.ensureDoc('parseStartXRef', [])
    }).then(() => {
      return pdfManager.ensureDoc('parse')
    }).then(() => {
      console.log("Xref entries", pdfManager.pdfDocument.catalog.xref.entries)
    })
  })
})

