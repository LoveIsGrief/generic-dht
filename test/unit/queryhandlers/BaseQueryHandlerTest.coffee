common = require('../../common')
BaseQueryHandler = require('../../../src/queryhandlers/BaseQueryHandler')
test = common.test

test "BaseQueryHandler", (t)->
  bqh = new BaseQueryHandler()
  t.test "checkMessage", (t)->
    goodMessage = {
      a: {}
      q: "__REPLACE_THIS__"
    }

    t.test "bad message", (t)->
      message = undefined
      func = bqh.checkMessage.bind bqh, message
      t.throws func, /No message/, "Undefined message"

      message = null
      func = bqh.checkMessage.bind bqh, message
      t.throws func, /No message/, "Null message"

      t.end()


    t.test "check a", (t)->
      t.test "no a", (t)->
        message = {}
        func = bqh.checkMessage.bind bqh, message

        t.throws func, /Arguments \('a'\)/, "No arguments in message dict"
        t.end()

      t.test "bad a", (t)->
        message = {
          a: "bad a"
        }
        func = bqh.checkMessage.bind bqh, message

        t.throws func, /not an object/, "Arguments are not a dict"
        t.end()
      t.test "good a", (t)->
        func = bqh.checkMessage.bind bqh, goodMessage
        t.doesNotThrow func, /not an object/, "Arguments are not a dict"
        t.end()


    t.test "check q", (t)->
      t.test "no q", (t)->
        message = {
          a: {}
        }
        func = bqh.checkMessage.bind bqh, message

        t.throws func, /Query name \('q'\)/, "No query name in message dict"
        t.end()

      t.test "bad q", ->
        message = {
          a: {}
          q: "nothing"
        }
        func = bqh.checkMessage.bind bqh, message

        t.throws func, /Cannot handle queries/, "No query name in message dict"
        t.end()

      t.test "good q", (t)->
        message = {
          a: {}
          q: "__REPLACE_THIS__"
        }
        func = bqh.checkMessage.bind bqh, message

        t.doesNotThrow func, /Cannot handle queries/, "No query name in message dict"
        t.end()
  t.test "getArgs", (t)->
    class ExtendedQueryHandler extends BaseQueryHandler
      @VALUES = [
        "one"
        "two"
        "three"
      ]
      @NAME = "extend"

    eqh = new ExtendedQueryHandler()
    t.test "good args", (t)->
      argsDict = {
        "one": 1
        "two": 2
        "three": 3
      }
      expected = [1, 2, 3]
      func = eqh.getArgs.bind eqh, argsDict
      t.doesNotThrow func, expected, "Right number of args with right names"
      t.end()
    t.test "good but not enough args", (t)->
      argsDict = {
        "one": 1
        "two": 2
      }
      func = eqh.getArgs.bind eqh, argsDict
      t.throws func, /'three' expected to be in arguments/, "'three' arg is missing"
      t.end()
    t.test "good but not enough args", (t)->
      argsDict = {
        "not good": "herp"
      }
      func = eqh.getArgs.bind eqh, argsDict
      t.throws func, /'one' expected to be in arguments/, "not even one good argument"
      t.end()
  t.test "handle", (t)->
    t.test "not implemented", (t)->
      goodMessage = {
        a:
          one: 1
          two: 2
          three: 3
        q: "__REPLACE_THIS__"
      }
      func = bqh.handle.bind bqh, goodMessage
      t.throws func, /not implemented/, "To be subclassed"
      t.end()


    t.test "subclassed", (t)->
      class TestQueryHandler extends BaseQueryHandler
        @VALUES = [
          "one"
          "two"
          "three"
        ]
        @NAME = "test"

        main: (one, two, three)->
          return arguments
      tqh = new TestQueryHandler()


      goodMessage = {
        a:
          one: 1
          two: 2
          three: 3
        q: "test"
      }
      t.test "good message", (t)->
        func = tqh.handle.bind tqh, goodMessage
        expected = [1, 2, 3]
        t.doesNotThrow func, expected, "call with correct values"
        t.end()
