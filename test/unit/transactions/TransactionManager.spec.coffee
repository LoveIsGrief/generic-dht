debug = require 'debug'
r = require('require-root')('generic-dht')
TransactionManager = r 'src/transactions/TransactionManager'
constants = r 'src/constants'

describe 'TransactionManager', ()->

  commonBeforeEach = ()->
    @responseCb = jasmine.createSpy 'responseCb'
    @errorCb = jasmine.createSpy 'errorCb'
    @manager = new TransactionManager @responseCb, @errorCb
    @address = 'somewhereonthenet'
    @messageType = 'test'

  beforeEach commonBeforeEach

  it 'should not create a new transaction without an address', ()->
    id = @manager.getNewTransactionId()
    expect(id).toBeNull()

  it 'should not create a new transaction without a messageType', ()->
    id = @manager.getNewTransactionId(null, null)
    expect(id).toBeNull()

  it 'should create a new transaction with and address and messageType', ()->
    id = @manager.getNewTransactionId @address, @messageType
    expect(id).not.toBeNull()
    expect(id).not.toBeUndefined()

    transaction = @manager.getTransaction @address, id
    expect(transaction).not.toBeNull()
    expect(transaction).not.toBeUndefined()
    expect(transaction.address).toEqual @address
    expect(transaction.id).toEqual id

  describe 'transactions', ()->


    beforeEach ()->
      commonBeforeEach.call @

      jasmine.clock().install()
      @transactionResponseCb = jasmine.createSpy 'transactionResponseCb'
      @transactionErrorCb = jasmine.createSpy 'transactionErrorCb'
      spyOn(@manager, '_clearTransaction').and.callThrough()
      @id = @manager.getNewTransactionId @address,
        @messageType,
        @transactionResponseCb,
        @transactionErrorCb
      @transaction = @manager.getTransaction @address, @id

      @responseCallbacks = [
        @responseCb
        @transactionResponseCb
      ]
      @errorCallbacks = [
        @errorCb
        @transactionErrorCb
      ]
      @callbacks = @responseCallbacks.concat @errorCallbacks


    afterEach ()->
      jasmine.clock().uninstall()

    it 'should timeout and finalize once', ()->
      responseCallbacks = [
        @responseCb
        @transactionResponseCb
      ]
      errorCallbacks = [
        @errorCb
        @transactionErrorCb
      ]

      for callback in responseCallbacks
        expect(callback).not.toHaveBeenCalled()
      for callback in errorCallbacks
        expect(callback).not.toHaveBeenCalled()

      jasmine.clock().tick(constants.SEND_TIMEOUT + 1)

      for callback in responseCallbacks
        expect(callback).not.toHaveBeenCalled()
      for callback in errorCallbacks
        expect(callback).toHaveBeenCalled()

      expect(@manager._clearTransaction).toHaveBeenCalledTimes 1

    it 'should respond', ()->
      for callback in @callbacks
        expect(callback).not.toHaveBeenCalled()

      @transaction.respond 'a response'

      for callback in @responseCallbacks
        expect(callback).toHaveBeenCalled()
