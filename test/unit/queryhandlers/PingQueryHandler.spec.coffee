common = require('../../common')
PingQueryHandler = require('../../../src/queryhandlers/PingQueryHandler')


describe 'PingQueryHandler', ()->

  it "should respond to 'ping' message", ()->

    message = {
      q: 'ping'
      a: {
        id: 'source id'
      }
    }
    queryHandler = new PingQueryHandler
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
    queryHandler = new PingQueryHandler nodeId
    expected = {
      id: nodeId
    }
    result = queryHandler.handle message
    expect(result).toEqual expected
