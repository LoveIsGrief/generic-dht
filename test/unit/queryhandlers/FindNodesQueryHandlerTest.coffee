common = require('../../common')
FindNodeQueryHandler = require(
  '../../../src/queryhandlers/FindNodeQueryHandler'
)
test = common.test
KBucket = require('k-bucket')

K = 20
MAX_CONCURRENCY = 1

test 'FindNodeQueryHandler', (t)->
  t.test "'responds to 'find_node' message'", (t)->
    message = {
      q: 'find_node'
      a: {
        id: 'nothing'
        target: 'unknown node'
      }
    }
    queryHandler = new FindNodeQueryHandler
    func = queryHandler.checkMessage.bind queryHandler, message
    t.doesNotThrow func, /Cannot handle/, "responds to 'find_node'"
    t.end()

  t.test 'handles good message', (t)->
    message = {
      q: 'find_node'
      a: {
        id: 'nothing'
        target: 'unknown node'
      }
    }
    nodes = new KBucket
      localNodeId: 'local node'
      numberOfNodesPerKBucket: K
      numberOfNodesToPing: MAX_CONCURRENCY
    nodeId = 'some node id'
    queryHandler = new FindNodeQueryHandler nodeId, nodes
    func = queryHandler.handle.bind queryHandler, message
    expected = {
      id: nodeId
      nodes: []
    }
    t.doesNotThrow func, expected, "executed 'find_node'"
    t.end()
