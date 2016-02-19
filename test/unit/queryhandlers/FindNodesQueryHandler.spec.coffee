common = require('../../common')
FindNodeQueryHandler = require(
  '../../../src/queryhandlers/FindNodeQueryHandler'
)
test = common.test
KBucket = require('k-bucket')

K = 20
MAX_CONCURRENCY = 1

describe 'FindNodeQueryHandler', ()->

  it "should respond to 'find_node' message", ()->

    message = {
      q: 'find_node'
      a: {
        id: 'nothing'
        target: 'unknown node'
      }
    }
    queryHandler = new FindNodeQueryHandler
    func = queryHandler.checkMessage.bind queryHandler, message
    expect(func).not.toThrowError /Cannot handle/

  it 'should handle good message', ()->

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
    expected = {
      id: nodeId
      nodes: new Buffer('')
    }
    result = queryHandler.handle message
    expect(result).toEqual expected
