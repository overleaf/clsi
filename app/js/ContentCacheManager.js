/**
 * ContentCacheManager - maintains a cache of stream hashes from a PDF file
 */

const { callbackify } = require('util')
const fs = require('fs')
const crypto = require('crypto')

/**
 *
 * @param {String} contentDir path to directory where content hash files are cached
 * @param {String} filePath the pdf file to scan for streams
 */
async function update(contentDir, filePath) {
  const stream = fs.createReadStream(filePath)
  const extractor = new PdfStreamsExtractor()
  const ranges = []
  for await (const chunk of stream) {
    const pdfStreams = extractor.consume(chunk)
    for (const pdfStream of pdfStreams) {
      const hash = pdfStreamHash(pdfStream.buffers)
      ranges.push({ start: pdfStream.start, end: pdfStream.end, hash })
    }
  }
  return ranges
}

class PdfStreamsExtractor {
  constructor() {
    this.fileIndex = 0
    this.inStream = false
    this.streamStartIndex = 0
    this.buffers = []
  }

  consume(chunk) {
    let chunkIndex = 0
    const pdfStreams = []
    while (true) {
      if (!this.inStream) {
        // Not in a stream, look for stream start
        const index = chunk.indexOf('stream', chunkIndex)
        if (index === -1) {
          // Couldn't find stream start
          break
        }
        // Found stream start, start a stream
        this.inStream = true
        this.streamStartIndex = this.fileIndex + index
        chunkIndex = index
      } else {
        // In a stream, look for stream end
        const index = chunk.indexOf('endstream', chunkIndex)
        if (index === -1) {
          this.buffers.push(chunk.slice(chunkIndex))
          break
        }
        // add "endstream" part
        const endIndex = index + 9
        this.buffers.push(chunk.slice(chunkIndex, endIndex))
        pdfStreams.push({
          start: this.streamStartIndex,
          end: this.fileIndex + endIndex,
          buffers: this.buffers
        })
        this.inStream = false
        this.buffers = []
        chunkIndex = endIndex
      }
    }
    this.fileIndex += chunk.length
    return pdfStreams
  }
}

function pdfStreamHash(buffers) {
  const hash = crypto.createHash('sha256')
  for (const buffer of buffers) {
    hash.update(buffer)
  }
  return hash.digest('hex')
}

module.exports = { update: callbackify(update) }
