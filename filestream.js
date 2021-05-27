const { Stream } = require("pdfjs-dist/lib/core/stream");
const { LocalPdfManager } = require('pdfjs-dist/lib/core/pdf_manager');
const fs = require('fs')
const { MissingDataException } = require('pdfjs-dist/lib/core/core_utils')

class FileStream extends Stream {
  constructor(fh, start, length, dict, cachedBytes) {
    const dummy = Buffer.from("");
    super(dummy, start, length, dict);
    delete this.bytes
    this.fh = fh
    this.cachedBytes = cachedBytes || new Array();
    console.log("created new stream", start, length)
  }

  get length() {
    return this.end - this.start;
  }

  get isEmpty() {
    return this.length === 0;
  }

  _getPos(pos) {
    const found = this.cachedBytes.find(x => {
      return (x.start <= pos && pos < x.end)
    })
    return found
  }

  _getRange(begin, end) {
    const found = this.cachedBytes.find(x => {
      return (x.start <= begin && end <= x.end)
    })
    return found
  }

  requestRange(begin, end) {
    if (end - begin < 1024) { end = begin + 1024 }
    end = Math.min(end, this.length);
    const result = { start: begin, end: end, buffer: Buffer.alloc(end - begin, 0) }
    console.log("fh.read", 0, end - begin, begin)
    this.cachedBytes.push(result)
    return this.fh.read(result.buffer, 0, end - begin, begin)
  }

  ensureByte(pos) {
    if (this._getPos(pos)) {
      return; // we've got it in the cache 
    } else {
      throw new MissingDataException(pos, pos + 1);
    }
  }

  getByte() {
    //console.log("getByte", this.pos)
    const pos = this.pos
    if (this.pos >= this.end) {
      console.log("beyond end of file", this.pos, this.end)
      return -1;
    }
    this.ensureByte(pos)
    const found = this._getPos(pos)
    if (found) {
      // console.log("got byte", this.pos, String.fromCharCode(found.buffer[this.pos - found.start]))
      return found.buffer[this.pos++ - found.start]
    } else {
      console.error("couldn't find byte in cache")
    }
  }

  // for a range, end is not included (see Buffer.subarray for example)

  ensureBytes(length, forceClamped = false) {
    const pos = this.pos;
    console.log("ensureBytes", pos, length)
    if (this._getRange(pos, pos + length)) {
      console.log("got it in the cache")
      return // we've got it in the cache
    } else {
      console.log("we don't have it yet in the cache")
      throw new MissingDataException(pos, pos + length);
    }
  }

  getBytes(length, forceClamped = false) {
    console.log("getBytes", this.pos, length)
    const pos = this.pos;
    const strEnd = this.end;

    this.ensureBytes(length)

    const found = this._getRange(pos, pos + length)
    if (!found) {
      console.error("couldn't find bytes in cache")
    }
    // console.log("found", found)
    if (!length) {
      const subarray = found.buffer.subarray(pos - found.start, strEnd - found.start);
      // `this.bytes` is always a `Uint8Array` here.
      return forceClamped ? new Uint8ClampedArray(subarray) : subarray;
    }
    let end = pos + length;
    if (end > strEnd) {
      end = strEnd;
    }
    this.pos = end;
    const subarray = found.buffer.subarray(pos - found.start, end - found.start);
    // `this.bytes` is always a `Uint8Array` here.
    return forceClamped ? new Uint8ClampedArray(subarray) : subarray;
  }

  getByteRange(begin, end) {
    console.log("getByteRange")
    throw "not implemented"
    // if (begin < 0) {
    //   begin = 0;
    // }
    // if (end > this.end) {
    //   end = this.end;
    // }
    // return this.bytes.subarray(begin, end);
  }

  reset() {
    console.log("reset")
    this.pos = this.start;
  }

  moveStart() {
    console.log("movestart")
    this.start = this.pos;
  }

  makeSubStream(start, length, dict = null) {
    console.log("makesubstream", start, length)
    if (!length) {
      length = this.end - start
    }
    return new FileStream(this.fh, start, length, dict, this.cachedBytes);
  }
}


module.exports = { FileStream }