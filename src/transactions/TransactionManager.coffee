Transaction = require './Transaction'
utils = require '../utils'

###
Keeps track of transactions and allows us to create them as well.
###
class TransactionManager

  ###
  @param mainResponseCallback {Function}
  ###
  constructor: (@mainResponseCallback, @mainErrorCallback)->
    @transactionsPerAddress = {}
    @_debug = utils.debug(@)


  _buildOnReponseCallback: (
    address,
    transactionId,
    messageType,
    transactionCallback
  )->
    (response, fromAddress)=>
      @_clearTransaction address, transactionId
      if @mainResponseCallback
        @mainResponseCallback response, messageType, fromAddress
      if transactionCallback
        transactionCallback response, fromAddress

  _buildOnErrorCallback: (
    address,
    transactionId,
    messageType,
    transactionCallback,
  )->
    (error, response, fromAddress)=>
      @_clearTransaction address, transactionId
      if @mainErrorCallback
        @mainErrorCallback error, response, messageType, fromAddress
      if transactionCallback
        transactionCallback error, response, messageType, fromAddress

  # Cleans the transaction from the known transactions
  _onTransactionTimeout: (address, transactionId)->
    errorMessage = "Transaction timeout for #{address} - #{transactionId}"
    error = new Error errorMessage
    transaction = @getTransaction address,transactionId
    transaction.onError error, null, address
    @_clearTransaction address, transactionId


  _clearTransaction: (address, transactionId)->
    transaction = @getTransaction(address, transactionId)
    if transaction
      clearTimeout transaction.timeoutId
      delete @transactionsPerAddress[address][transactionId]


  ###
  Get a transaction id, and (optionally) set a function to be called
  @param  {string}   addr
  @param  {function} fn
  ###
  getNewTransactionId: (address, messageType, callback, errorCallback)->
    transactions = @transactionsPerAddress[address]
    if !transactions
      transactions = @transactionsPerAddress[address] = {}
      transactions.nextTransactionId = 0
    transactionId = transactions.nextTransactionId
    transactions.nextTransactionId += 1

    responseCallback = @_buildOnReponseCallback(
      address,
      transactionId,
      messageType,
      callback)
    errorCallback = @_buildOnErrorCallback(
      address,
      transactionId,
      messageType,
      errorCallback
    )

    transaction = new Transaction(
      address, transactionId
      responseCallback, errorCallback
    )
    transaction.on 'timeout',
      @_onTransactionTimeout.bind(@, address, transactionId)
    transactions[transactionId] = transaction
    transaction.id

  getTransaction: (address, id)->
    transactions = @transactionsPerAddress[address]
    if transactions
      transactions[id]
    else
      @_debug "No tranaction for #{address} - #{id} found"


module.exports = TransactionManager
