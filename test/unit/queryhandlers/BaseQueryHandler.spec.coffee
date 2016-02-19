common = require('../../common')
BaseQueryHandler = require('../../../src/queryhandlers/BaseQueryHandler')

describe 'BaseQueryHandler', ()->

  bqh = new BaseQueryHandler()


  describe 'the checkMessage method', ()->

    goodMessage = {
      a: {}
      q: '__REPLACE_THIS__'
    }

    it 'should fail with bad messages', ()->
      message = undefined
      func = bqh.checkMessage.bind bqh, message
      expect(func).toThrowError TypeError, /No message/

      message = null
      func = bqh.checkMessage.bind bqh, message
      expect(func).toThrowError TypeError, /No message/


    describe 'arguments in message.a', ()->

      it 'should fail with an empty a', ()->

        message = {}
        func = bqh.checkMessage.bind bqh, message

        expect(func).toThrowError /Arguments \('a'\)/

      it 'should fail with a bad a', ()->

        message = {
          a: 'bad a'
        }
        func = bqh.checkMessage.bind bqh, message

        expect(func).toThrowError /not an object/

      it 'should succeed with a good a', ()->

        func = bqh.checkMessage.bind bqh, goodMessage
        expect(func).not.toThrowError /not an object/


    describe 'query in message.q', ()->

      it 'should fail with no q', ()->

        message = {
          a: {}
        }
        func = bqh.checkMessage.bind bqh, message

        expect(func).toThrowError /Query name \('q'\)/

      it 'should fail with a bad q', ()->

        message = {
          a: {}
          q: 'nothing'
        }
        func = bqh.checkMessage.bind bqh, message

        expect(func).toThrowError /Cannot handle queries/

      it 'should succeed with a good q', ()->

        message = {
          a: {}
          q: '__REPLACE_THIS__'
        }
        func = bqh.checkMessage.bind bqh, message

        expect(func).not.toThrowError /Cannot handle queries/


  describe 'the getArgs method', ()->

    class ExtendedQueryHandler extends BaseQueryHandler
      @VALUES = [
        'one'
        'two'
        'three'
      ]
      @NAME = 'extend'


    eqh = new ExtendedQueryHandler()


    it 'should succeed with args', ()->
      argsDict = {
        one: 1
        two: 2
        three: 3
      }
      expected = [1, 2, 3]
      result = eqh.getArgs argsDict
      expect(result).toEqual expected

    it 'it should fail with good but insufficient args', ()->
      argsDict = {
        one: 1
        two: 2
      }
      func = eqh.getArgs.bind eqh, argsDict
      expect(func).toThrowError /'three' expected to be in arguments/

    it 'good but not enough args', ()->
      argsDict = {
        'not good': 'herp'
      }
      func = eqh.getArgs.bind eqh, argsDict
      expect(func).toThrowError /'one' expected to be in arguments/


  describe 'the handle method', ()->

    it 'should not be implemented', ()->

      goodMessage = {
        a:
          one: 1
          two: 2
          three: 3
        q: '__REPLACE_THIS__'
      }
      func = bqh.handle.bind bqh, goodMessage
      expect(func).toThrowError /not implemented/


    describe 'when subclassed', ()->

      class TestQueryHandler extends BaseQueryHandler
        @VALUES = [
          'one'
          'two'
          'three'
        ]
        @NAME = 'test'

        main: (one, two, three)->
          [one, two, three]
      tqh = new TestQueryHandler()


      goodMessage = {
        a:
          one: 1
          two: 2
          three: 3
        q: 'test'
      }
      it 'should work with a good message', ()->

        expected = [1, 2, 3]
        result = tqh.handle goodMessage
        expect(result).toEqual expected
