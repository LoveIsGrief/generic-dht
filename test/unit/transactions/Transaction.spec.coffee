r = require('require-root')('generic-dht')
Transaction = r 'src/transactions/Transaction'
constants = r 'src/constants'

describe 'Transaction', ()->


  describe 'timeouts', ()->

    beforeEach ()->
      jasmine.clock().install()
      @address = '127.0.0.1:1337'
      @id = 0
      @transaction = new Transaction @address, @id

    afterEach ()->
      jasmine.clock().uninstall()

    it 'should timeout', ()->
      toBeCalled = jasmine.createSpy('timerCallback')

      @transaction.on 'timeout', toBeCalled

      expect(toBeCalled).not.toHaveBeenCalled()
      jasmine.clock().tick(constants.SEND_TIMEOUT+1)
      expect(toBeCalled).toHaveBeenCalledWith @address, @id

  describe 'finalize', ()->

    commonBeforeEach = ()->
      @address = '127.0.0.1:1337'
      @id = 0
      @transaction = new Transaction @address, @id
      @finalCb = jasmine.createSpy 'finalize'
      @tDebug = jasmine.createSpy 'debug'
      @transaction._debug = @tDebug

    describe 'unfinalized', ()->

      beforeEach commonBeforeEach

      it 'should be finalized without a prefix callback', ()->
        @transaction.on 'finalize', @finalCb
        expect(@finalCb).not.toHaveBeenCalled()
        @transaction.finalize()
        expect(@finalCb).toHaveBeenCalled()
        expect(@transaction.finalized).toBe true

      it 'should be finalized with a prefix callback', ()->
        prefixCb = jasmine.createSpy 'prefix'
        @transaction.on 'finalize', @finalCb
        expect(@finalCb).not.toHaveBeenCalled()
        expect(prefixCb).not.toHaveBeenCalled()

        @transaction.finalize prefixCb

        expect(@finalCb).toHaveBeenCalled()
        expect(prefixCb).toHaveBeenCalled()
        expect(@transaction.finalized).toBe true

    describe 'already finalized', ()->

      beforeEach ()->
        commonBeforeEach.call @
        @transaction.finalize()

      it 'should not be finalized again', ()->
        @transaction.on 'finalize', @finalCb
        expect(@finalCb).not.toHaveBeenCalled()
        expect(@tDebug).not.toHaveBeenCalled()

        # Second call
        @transaction.finalize()
        expect(@finalCb).not.toHaveBeenCalled()
        expect(@tDebug).toHaveBeenCalledWith 'Already finalized'
        expect(@transaction.finalized).toBe true

      it 'should log custom debug second time', ()->
        expect(@tDebug).not.toHaveBeenCalled()

        customMessage = 'Customs already finalized'
        # Second
        @transaction.finalize null, customMessage
        expect(@tDebug).toHaveBeenCalledWith customMessage
