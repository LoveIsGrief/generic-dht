crypto = require('crypto')
hat = require('hat')
ip = require('ip')

test = require('tape')
tapSpec = require('tap-spec')

test.createStream().pipe(tapSpec()).pipe(process.stdout)
exports.test = test

exports.failOnWarningOrError = (t, dht) ->
  dht.on 'warning', (err) ->
    t.fail err
  dht.on 'error', (err) ->
    t.fail err

exports.randomAddr = ->
  host = ip.toString(crypto.randomBytes(4))
  port = crypto.randomBytes(2).readUInt16LE(0)
  host + ':' + port

exports.randomId = ->
  new Buffer(hat(160), 'hex')

exports.addRandomNodes = (dht, num) ->
  i = 0
  while i < num
    dht.addNode exports.randomAddr(), exports.randomId()
    i++
