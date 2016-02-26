events = require 'events'
constants = require '../constants'
utils = require '../utils'

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

@event response - notify there's a response for the transaction
  @param response {Object}

@event error - notify errors in the transaction
  @param error {String, Error}
  @param response {Object}

@event finalize - put in a final state where no more actions are possible
  @param address {String} IP:port
  @param id {Integer}
###
class Transaction extends events.EventEmitter


  ###
  @param address {String}
  @param id {Integer}
  @param timeout {Number} How many milliseconds to wait until a timeout
  ###
  constructor: (
    @address,
    @id,
    timeout = constants.SEND_TIMEOUT
  )->
    @_debug = utils.debug @
    @finalized = false
    onTimeout = @_onTimeout.bind @
    @timeoutId = setTimeout onTimeout, timeout

  toString: ()->
    "Transaction[#{@timeoutId}] #{@address} - #{@id} | finalized:#{@finalized}"

  ###
  Put in a state where no more actions can be taken.

  @param prefixFn {Function} Called before finalizing
  @param message {String} Log in case we are already finalized
  ###
  finalize: (prefixFn, message='Already finalized')->
    if !@finalized
      clearTimeout @timeoutId
      prefixFn() if prefixFn
      @finalized = true
      @emit 'finalize', @address, @id
    else
      @_debug message

  ###
  Notify of a response

  @param response {Object}

  @event response
  @event finalize
  ###
  respond: (response)->
    @finalize ()=>
      @emit 'response', response, @address
    , 'already received response from', @address, ' id:', @id

  ###
  Notify of an error

  @param response {Object}

  @event error
  @event finalize
  ###
  error: (error, response)->
    @finalize ()=>
      @emit 'error', error, response, @address
    , 'already received response from', @address, ' id:', @id


  ###
  Cleanup once the transaction has timed out
  @event timeout
  @event finalize
  ###
  _onTimeout: ()->
    @finalize ()=>
      @emit 'timeout', @address, @id


module.exports = Transaction
