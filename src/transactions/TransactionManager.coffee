_ = require 'lodash'
Transaction = require './Transaction'
utils = require '../utils'

###
Keeps track of transactions and allows us to create them as well.
###
class TransactionManager

  ###
  Remembers 'global' callbacks that will be assigned to each transaction.

  @param mainResponseCallback {Function} callback
    for @see {Transaction}.response event
  @param errorResponseCallback {Function} callback
    for @see {Transaction}.error event
  ###
  constructor: (@mainResponseCallback, @mainErrorCallback)->
    @transactionsPerAddress = {}
    @_debug = utils.debug(@)


  _buildOnResponseCallback: (messageType)->
    (response, fromAddress)=>
      @_debug fromAddress, ' responded ', response
      if @mainResponseCallback
        @mainResponseCallback response, messageType, fromAddress

  _buildOnErrorCallback: (messageType)->
    (error, response, fromAddress)=>
      @_debug fromAddress, ' errored ', error
      if @mainErrorCallback
        @mainErrorCallback error, response, messageType, fromAddress


  _onTransactionTimeout: (address, transactionId)->
    transaction = @getTransaction address,transactionId
    if transaction
      errorMessage = "Transaction timeout for #{address} - #{transactionId}"
      error = new Error errorMessage
      transaction.error error, null

  ###
  Cleans the transaction from the known transactions
  ###
  _clearTransaction: (address, transactionId)->
    transaction = @getTransaction(address, transactionId)
    if transaction
      clearTimeout transaction.timeout
      delete @transactionsPerAddress[address][transactionId]


  ###
  Create a new transaction and get its ID

  The transaction will have 'global' callbacks
  and also the here given callbacks

  @param address {String} Target
  @param messageType {String} an identifier for the kind of message being sent
  @param responseCallback {Function} @see {Transaction}.response event
  @param errorCallback {Function} @see {Transaction}.error event
  ###
  getNewTransactionId: (
    address,
    messageType,
    responseCallback=_.noop,
    errorCallback=_.noop
  )->
    if not (address or messageType)
      return null

    transactions = @transactionsPerAddress[address]
    if !transactions
      transactions = @transactionsPerAddress[address] = {}
      transactions.nextTransactionId = 0
    transactionId = transactions.nextTransactionId
    transactions.nextTransactionId += 1

    transaction = new Transaction(address, transactionId)
    transaction.on 'finalize', @_clearTransaction.bind(@)
    transaction.on 'response', @_buildOnResponseCallback(messageType)
    transaction.on 'response', responseCallback
    transaction.on 'error', @_buildOnErrorCallback(messageType)
    transaction.on 'error', errorCallback
    transaction.on 'timeout', @_onTransactionTimeout.bind(@)
    transactions[transactionId] = transaction
    transaction.id

  ###
  Attempts to find the transaction.

  @return {Transmission | null}
  ###
  getTransaction: (address, id)->
    transactions = @transactionsPerAddress[address]
    if transactions
      transactions[id]
    else
      @_debug "No tranaction for #{address} - #{id} found"
      null


module.exports = TransactionManager
