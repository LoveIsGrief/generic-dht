events = require 'events'
constants = require '../constants'

###
Holds information about a query sent to another node.

@example Response linked to transaction
  query(args...)
  .then (response, address)->
    transaction = # get transaction ...
    transaction.response response
  .catch (error, response, address)->
    transaction = # get transaction ...
    transaction.error error, response

@event timeout
@event response - should be emitted externally
  @param response {Object}
  @param address {String}
@event error - should be emitted externally
  @param erro {String, Error}
  @param response {Object}
  @param address {String}
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
    timeout = constants.SEND_TIMEOUT
  )->
    @finalized = false
    onTimeout = @_onTimeout.bind @
    @timeoutId = setTimeout onTimeout, timeout

  respond: (response)->
    @emit 'finalize', @address, @id
    @emit 'respond', response, @address

  error: (error, response)->
    @emit 'finalize', @address, @id
    @emit 'error', error, response, @address


  ###
  Cleanup once the transaction has timed out
  @event timeout
  ###
  _onTimeout: ()->
    clearTimeout @timeoutId
    @emit 'timeout', @


module.exports = Transaction
