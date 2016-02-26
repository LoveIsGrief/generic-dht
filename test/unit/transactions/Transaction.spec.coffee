r = require('require-root')('generic-dht')
Transaction = r 'src/transactions/Transaction'
constants = r 'src/constants'

describe 'Transaction', ()->


  describe 'timeouts', ()->

    beforeEach ()->
      jasmine.clock().install()
      @address = '127.0.0.1:1337'
      @id = 0

    it 'should timeout', ()->
      toBeCalled = jasmine.createSpy('timerCallback')

      t = new Transaction @address, @id
      t.on 'timeout', toBeCalled

      expect(toBeCalled).not.toHaveBeenCalled()
      jasmine.clock().tick(constants.SEND_TIMEOUT+1)
      expect(toBeCalled).toHaveBeenCalledWith @address, @id
