const { Stream } = require("pdfjs-dist/lib/core/stream");
const { MissingDataException } = require('pdfjs-dist/lib/core/core_utils')
const fs = require('fs')

const BUF_SIZE = 1024 // read from the file in 1024 byte pages
class FileStream extends Stream {
  constructor(fh, start, length, dict, cachedBytes) {
    const dummy = Buffer.from("");
    super(dummy, start, length, dict);
    delete this.bytes
    this.fh = fh
    this.cachedBytes = cachedBytes || new Array();
  }

  get length() {
    return this.end - this.start;
  }

  get isEmpty() {
    return this.length === 0;
  }

  // Manage cached reads from the file

  requestRange(begin, end) {
    // expand small ranges to read a larger amount
    if (end - begin < BUF_SIZE) { end = begin + BUF_SIZE }
    end = Math.min(end, this.length);
    // keep a cache of previous reads with {begin,end,buffer} values 
    const result = { begin: begin, end: end, buffer: Buffer.alloc(end - begin, 0) }
    this.cachedBytes.push(result)
    return this.fh.read(result.buffer, 0, end - begin, begin)
  }

  _getPos(pos) {
    const found = this.cachedBytes.find(x => {
      return (x.begin <= pos && pos < x.end)
    })
    return found
  }

  _getRange(begin, end) {
    const found = this.cachedBytes.find(x => {
      return (x.begin <= begin && end <= x.end)
    })
    return found
  }

  _readByte(found, pos) {
    return found.buffer[pos - found.begin]
  }

  _readBytes(found, pos, end) {
    return found.buffer.subarray(pos - found.begin, end - found.begin);
  }

  // handle accesses to the bytes

  ensureByte(pos) {
    if (this._getPos(pos)) {
      return; // we've got it in the cache 
    } else {
      throw new MissingDataException(pos, pos + 1);
    }
  }

  getByte() {
    const pos = this.pos
    if (this.pos >= this.end) {
      return -1;
    }
    this.ensureByte(pos)
    const found = this._getPos(pos)
    if (found) {
      return this._readByte(found, this.pos++)
    } else {
      console.error("couldn't find byte in cache - shouldn't happen")
    }
  }

  // BG: for a range, end is not included (see Buffer.subarray for example)

  ensureBytes(length, forceClamped = false) {
    const pos = this.pos;
    if (this._getRange(pos, pos + length)) {
      return // we've got it in the cache
    } else {
      throw new MissingDataException(pos, pos + length);
    }
  }

  getBytes(length, forceClamped = false) {
    const pos = this.pos;
    const strEnd = this.end;

    this.ensureBytes(length)

    const found = this._getRange(pos, pos + length)
    if (!found) {
      console.error("couldn't find bytes in cache - shouldn't happen")
    }
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
    const subarray = this._readBytes(found, pos, end)
    // `this.bytes` is always a `Uint8Array` here.
    return forceClamped ? new Uint8ClampedArray(subarray) : subarray;
  }

  getByteRange(begin, end) {
    throw "not implemented"  // this isn't needed as far as I can tell
    // if (begin < 0) {
    //   begin = 0;
    // }
    // if (end > this.end) {
    //   end = this.end;
    // }
    // return this.bytes.subarray(begin, end);
  }

  reset() {
    this.pos = this.start;
  }

  moveStart() {
    this.start = this.pos;
  }

  makeSubStream(start, length, dict = null) {
    // BG: had to add this check for null length, it is being called with only
    // the start value at one point in the xref decoding. The intent is clear
    // enough
    // - a null length means "to the end of the file" -- not sure how it is
    //   working in the existing pdfjs code without this.
    if (!length) {
      length = this.end - start
    }
    return new FileStream(this.fh, start, length, dict, this.cachedBytes);
  }
}


module.exports = { FileStream }