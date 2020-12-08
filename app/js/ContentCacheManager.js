let ContentCacheManager
const fs = require('fs')
const Path = require('path')
const logger = require('logger-sharelatex')
const Settings = require('settings-sharelatex')
const crypto = require('crypto')

// ContentCacheManager - maintains a cache of stream hashes from a PDF file

module.exports = ContentCacheManager = {
  /**
   *
   * @param {*} contentDir path to directory where content hash files are cached
   * @param {*} file the pdf file to scan for streams
   * @param {*} callback   (err, rangeList)
   */
  update(contentDir, file, callback) {
    console.log(
      'CONTENTCACHEMANAGER: IN CONTENTDIR',
      contentDir,
      'CACHE STREAMS FROM',
      file
    )
    // scan the file for begin/end stream markers (subject to a minimum size, e.g. 64k)
    // compute the sha256 hash of the stream content between the markers
    // append the begin/end position and hash to the rangeList
    // look for a file in the contentdir with the hash as the name.
    // if not present, write the content in the range from begin to end into the file.
    // SOMEDAY: clean the directory by removing old hash files
    const rangeList = []
    callback(null, rangeList)
  },
}
