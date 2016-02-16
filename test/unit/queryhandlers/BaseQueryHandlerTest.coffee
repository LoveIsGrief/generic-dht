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
