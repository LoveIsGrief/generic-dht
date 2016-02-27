r = require('require-root')('generic-dht')
TransactionManager = r 'src/transactions/TransactionManager'

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

