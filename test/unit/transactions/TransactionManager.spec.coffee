r = require('require-root')('generic-dht')
TransactionManager = r 'src/transactions/TransactionManager'

describe 'TransactionManager', ()->

  beforeEach ()->
    @responseCb = jasmine.createSpy 'responseCb'
    @errorCb = jasmine.createSpy 'errorCb'
    @manager = new TransactionManager @responseCb, @errorCb

  it 'should not create a new transaction without an address', ()->
    id = @manager.getNewTransactionId()
    expect(id).toBeNull()
