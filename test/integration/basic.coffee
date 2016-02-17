common = require('./../common')
DHT = require('../../')

test = common.test

test 'explicitly set nodeId', (t) ->
  nodeId = common.randomId()
  dht = new DHT(
    nodeId: nodeId
    bootstrap: false)
  common.failOnWarningOrError t, dht
  t.equal dht.nodeId, nodeId
  t.end()

test '`ping` query send and response', (t) ->
  t.plan 2
  dht1 = new DHT(bootstrap: false)
  dht2 = new DHT(bootstrap: false)
  common.failOnWarningOrError t, dht1
  common.failOnWarningOrError t, dht2
  dht1.listen ->
    dht2._sendPing '127.0.0.1:' + dht1.address().port, (err, res) ->
      t.error err
      t.deepEqual res.id, dht1.nodeId
      dht1.destroy()
      dht2.destroy()

test '`find_node` query for exact match (with one in table)', (t) ->
  t.plan 3
  targetNodeId = common.randomId()
  dht1 = new DHT(bootstrap: false)
  dht2 = new DHT(bootstrap: false)
  common.failOnWarningOrError t, dht1
  common.failOnWarningOrError t, dht2
  dht1.addNode '255.255.255.255:6969', targetNodeId
  dht1.listen ->
    dht2._sendFindNode '127.0.0.1:' + dht1.address().port, targetNodeId, (err, res) ->
      t.error err
      t.deepEqual res.id, dht1.nodeId, "same nodeid"
      t.deepEqual res.nodes.map((node) ->
        node.addr
      ), [
        '255.255.255.255:6969'
        '127.0.0.1:' + dht2.address().port
      ], "same nodes"
      dht1.destroy()
      dht2.destroy()

test '`find_node` query (with many in table)', (t) ->
  t.plan 3
  dht1 = new DHT(bootstrap: false)
  dht2 = new DHT(bootstrap: false)
  common.failOnWarningOrError t, dht1
  common.failOnWarningOrError t, dht2
  dht1.addNode '1.1.1.1:6969', common.randomId()
  dht1.addNode '10.10.10.10:6969', common.randomId()
  dht1.addNode '255.255.255.255:6969', common.randomId()
  dht1.listen ->
    targetNodeId = common.randomId()
    dht2._sendFindNode '127.0.0.1:' + dht1.address().port, targetNodeId, (err, res) ->
      t.error err
      t.deepEqual res.id, dht1.nodeId
      t.deepEqual res.nodes.map((node) ->
        node.addr
      ).sort(), [
        '1.1.1.1:6969'
        '10.10.10.10:6969'
        '127.0.0.1:' + dht2.address().port
        '255.255.255.255:6969'
      ]
      dht1.destroy()
      dht2.destroy()
