crypto = require('crypto')
deepEqual = require('deep-equal')
hat = require('hat')
ip = require('ip')

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

exports.jasmineMatchers = {
  toDeepEqual: (util, customEqualityTesters)->
    compare: (actual, expected)->
      result = pass: deepEqual(actual, expected)
      if result.pass
        result.message = "actual #{actual} deep-equals #{expected}"
      else
        result.message = "actual #{actual} are not deep-equal #{expected}"

      result
}
