const { Stream } = require("pdfjs-dist/lib/core/stream");
const { LocalPdfManager } = require('pdfjs-dist/lib/core/pdf_manager');
const fs = require('fs')
const { MissingDataException } = require('pdfjs-dist/lib/core/core_utils')

class FSStream extends Stream {
  constructor(fd, start, length, dict) {
    const dummy = Buffer.from("dummy-stream");
    super(dummy, start, 9999, dict);
    this.fd = fd
    this.bytes = new Uint8Array()
    this.start = start || 0;
    this.pos = this.start;
    this.end = start + length || this.bytes.length;
    this.dict = dict;
    this.cachedBytes = new Array();
  }

  get length() {
    return this.end - this.start;
  }

  get isEmpty() {
    return this.length === 0;
  }

  ensureByte(pos) {
    if (this.cachedBytes.some(x => {
      return (x.start <= pos && pos < x.end)
    })) {
      return; // we've got it in the cache 
    } else {
      throw new MissingDataException(pos, pos + 1);
    }
  }

  getByte() {
    console.log("getByte", this.pos)
    if (this.pos >= this.end) {
      return -1;
    }

    return this.bytes[this.pos++];
  }

  ensureBytes(length, forceClamped = false) {
    const pos = this.pos;
    console.log("ensureBytes", length)
    if (this.cachedBytes.some(x => {
      return (x.start <= pos && pos + length < x.end)
    })) {
      return // we've got it in the cache
    } else {
      throw new MissingDataException(pos, pos + length);
    }
  }

  getBytes(length, forceClamped = false) {
    console.log("getBytes", this.pos, length)
    const bytes = this.bytes;
    const pos = this.pos;
    const strEnd = this.end;

    this.ensureBytes(length)

    if (!length) {
      const subarray = bytes.subarray(pos, strEnd);
      // `this.bytes` is always a `Uint8Array` here.
      return forceClamped ? new Uint8ClampedArray(subarray) : subarray;
    }
    let end = pos + length;
    if (end > strEnd) {
      end = strEnd;
    }
    this.pos = end;
    const subarray = bytes.subarray(pos, end);
    // `this.bytes` is always a `Uint8Array` here.
    return forceClamped ? new Uint8ClampedArray(subarray) : subarray;
  }

  getByteRange(begin, end) {
    console.log("getByteRange")
    if (begin < 0) {
      begin = 0;
    }
    if (end > this.end) {
      end = this.end;
    }
    return this.bytes.subarray(begin, end);
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
    console.log("makesubstream")
    return new FSStream(this.bytes.buffer, start, length, dict);
  }
}

class FSStreamManager {
  constructor(pdfNetworkStream, args) {
    this.length = args.length;
    this.chunkSize = args.rangeChunkSize;
    this.stream = new ChunkedStream(this.length, this.chunkSize, this);
    this.pdfNetworkStream = pdfNetworkStream;
    this.disableAutoFetch = args.disableAutoFetch;
    this.msgHandler = args.msgHandler;

    this.currRequestId = 0;

    this._chunksNeededByRequest = new Map();
    this._requestsByChunk = new Map();
    this._promisesByRequest = new Map();
    this.progressiveDataLength = 0;
    this.aborted = false;

    this._loadedStreamCapability = createPromiseCapability();
  }
}


module.exports = { FSStream, FSStreamManager }