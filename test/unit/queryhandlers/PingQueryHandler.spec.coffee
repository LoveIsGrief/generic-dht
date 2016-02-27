r = require('require-root')('generic-dht')
common = r('test/common')
PingQueryHandler = r('src/queryhandlers/PingQueryHandler')


describe 'PingQueryHandler', ()->

  it "should respond to 'ping' message", ()->

    message = {
      q: 'ping'
      a: {
        id: 'source id'
      }
    }
    queryHandler = new PingQueryHandler {nodeId: 'aPingNode'}
    func = queryHandler.checkMessage.bind queryHandler, message
    expect(func).not.toThrowError /Cannot handle/

  it "should handle a good 'ping' message", ()->

    message = {
      q: 'ping'
      a: {
        id: 'source id'
      }
    }
    nodeId = 'some node id'
    queryHandler = new PingQueryHandler {nodeId: nodeId}
    expected = {
      id: nodeId
    }
    result = queryHandler.handle message
    expect(result).toEqual expected
