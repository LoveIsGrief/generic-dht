common = require('./../common')
DHT = require('../../')

describe "Basic DHT tests", ()->


  it 'should explicitly set nodeId',()->

    nodeId = common.randomId()
    dht = new DHT(
      nodeId: nodeId
      bootstrap: false)
    common.failOnWarningOrError t, dht
    expect(dht.nodeId).toEqual nodeId

  it 'should `ping` query send and response', (done) ->
    dht1 = new DHT(bootstrap: false)
    dht2 = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht1
    common.failOnWarningOrError done, dht2
    dht1.listen ->
      dht2._sendPing '127.0.0.1:' + dht1.address().port, (err, res) ->
        expect(err).toBeUndefined()
        expect(res.id).toEqual dht1.nodeId
        dht1.destroy()
        dht2.destroy()
        done()

  it 'should `find_node` query for exact match (with one in table)', (done) ->
    targetNodeId = common.randomId()
    dht1 = new DHT(bootstrap: false)
    dht2 = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht1
    common.failOnWarningOrError done, dht2
    dht1.addNode '255.255.255.255:6969', targetNodeId
    dht1.listen ->
      dht2._sendFindNode '127.0.0.1:' + dht1.address().port,
        targetNodeId,
        (err, res) ->
          done.error err
          done.deepEqual res.id, dht1.nodeId, 'same nodeid'
          done.deepEqual res.nodes.map((node) ->
            node.addr
          ), [
            '255.255.255.255:6969'
            '127.0.0.1:' + dht2.address().port
          ], 'same nodes'
          dht1.destroy()
          dht2.destroy()
          done()

  it 'should `find_node` query (with many in table)', (done) ->
    dht1 = new DHT(bootstrap: false)
    dht2 = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht1
    common.failOnWarningOrError done, dht2
    dht1.addNode '1.1.1.1:6969', common.randomId()
    dht1.addNode '10.10.10.10:6969', common.randomId()
    dht1.addNode '255.255.255.255:6969', common.randomId()
    dht1.listen ->
      targetNodeId = common.randomId()
      dht2._sendFindNode '127.0.0.1:' + dht1.address().port,
        targetNodeId,
        (err, res) ->
          expect(err).toBeUndefined()
          expect(res.id).toEqual dht1.nodeId
          expectedNodes =  [
            '1.1.1.1:6969'
            '10.10.10.10:6969'
            '127.0.0.1:' + dht2.address().port
            '255.255.255.255:6969'
          ]
          resultingNodes = res.nodes.map((node) ->
            node.addr
          ).sort()
          expect(resultingNodes).toEqual expectedNodes
          dht1.destroy()
          dht2.destroy()
          done()
