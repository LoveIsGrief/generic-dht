events = require 'events'
constants = require '../constants'

###
Holds information about a query sent to another node.

Allows us to take action

@event timeout
###
class Transaction extends events.EventEmitter


  ###
  @param address {String}
  @param id {Integer}
  @param onResponse {Function}
  @param onError {Function}
  @param timeout {Number} How many milliseconds to wait until a timeout
  ###
  constructor: (
    @address,
    @id,
    @onResponse,
    @onError,
    timeout = constants.SEND_TIMEOUT
  )->

    onTimeout = @_onTimeout.bind @
    @timeoutId = setTimeout onTimeout, timeout

  ###
  Overwritten in the constructor

  @param response {Object}
  @param fromAddress {String}
  ###
  onResponse: (response, fromAddress)->

  ###
  Overwritten in the constructor

  @param error {String, Error}
  @param response {Object}
  @param fromAddress {String}
  ###
  onError: (error, response, fromAddress)->

  ###
  Cleanup once the transaction has timed out
  @event timeout
  ###
  _onTimeout: ()->
    clearTimeout @timeoutId
    @emit 'timeout', @


module.exports = Transaction
