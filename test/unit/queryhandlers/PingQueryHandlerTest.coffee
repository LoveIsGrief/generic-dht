common = require('../../common')
PingQueryHandler = require('../../../src/queryhandlers/PingQueryHandler')
test = common.test


test "PingQueryHandler", (t)->
  t.test "responds to 'ping' message", (t)->
    message = {
      q: "ping"
      a: {
        "id": "source id"
      }
    }
    queryHandler = new PingQueryHandler
    func = queryHandler.checkMessage.bind queryHandler, message
    t.doesNotThrow func, /Cannot handle/, "responds to 'ping'"
    t.end()

  t.test "handles good message", (t)->
    message = {
      q: "ping"
      a: {
        "id": "source id"
      }
    }
    nodeId = "some node id"
    queryHandler = new PingQueryHandler nodeId
    func = queryHandler.handle.bind queryHandler, message
    expected = {
      id: nodeId
    }
    t.doesNotThrow func, expected, "executed 'ping'"
    t.end()

