common = require('./common')
DHT = require('../')
test = require('tape')

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
      t.deepEqual res.id, dht1.nodeId
      t.deepEqual res.nodes.map((node) ->
        node.addr
      ), [
        '255.255.255.255:6969'
        '127.0.0.1:' + dht2.address().port
      ]
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

test '`get_peers` query to node with *no* peers in table', (t) ->
  t.plan 4
  dht1 = new DHT(bootstrap: false)
  dht2 = new DHT(bootstrap: false)
  common.failOnWarningOrError t, dht1
  common.failOnWarningOrError t, dht2
  dht1.addNode '1.1.1.1:6969', common.randomId()
  dht1.addNode '2.2.2.2:6969', common.randomId()
  dht1.listen ->
    targetInfoHash = common.randomId()
    dht2._sendGetPeers '127.0.0.1:' + dht1.address().port, targetInfoHash, (err, res) ->
      t.error err
      t.deepEqual res.id, dht1.nodeId
      t.ok Buffer.isBuffer(res.token)
      t.deepEqual res.nodes.map((node) ->
        node.addr
      ).sort(), [
        '1.1.1.1:6969'
        '127.0.0.1:' + dht2.address().port
        '2.2.2.2:6969'
      ]
      dht1.destroy()
      dht2.destroy()

test '`get_peers` query to node with peers in table', (t) ->
  t.plan 4
  dht1 = new DHT(bootstrap: false)
  dht2 = new DHT(bootstrap: false)
  common.failOnWarningOrError t, dht1
  common.failOnWarningOrError t, dht2
  targetInfoHash = common.randomId()
  dht1._addPeer '1.1.1.1:6969', targetInfoHash
  dht1._addPeer '10.10.10.10:6969', targetInfoHash
  dht1._addPeer '255.255.255.255:6969', targetInfoHash
  dht1.listen ->
    dht2._sendGetPeers '127.0.0.1:' + dht1.address().port, targetInfoHash, (err, res) ->
      t.error err
      t.deepEqual res.id, dht1.nodeId
      t.ok Buffer.isBuffer(res.token)
      t.deepEqual res.values.sort(), [
        '1.1.1.1:6969'
        '10.10.10.10:6969'
        '255.255.255.255:6969'
      ]
      dht1.destroy()
      dht2.destroy()

test '`announce_peer` query with bad token', (t) ->
  t.plan 2
  dht1 = new DHT(bootstrap: false)
  dht2 = new DHT(bootstrap: false)
  common.failOnWarningOrError t, dht1
  common.failOnWarningOrError t, dht2
  infoHash = common.randomId()
  dht1.listen ->
    token = new Buffer('bad token')
    dht2._sendAnnouncePeer '127.0.0.1:' + dht1.address().port, infoHash, 9999, token, (err, res) ->
      t.ok err, 'got error'
      t.ok err.message.indexOf('bad token') != -1
      dht1.destroy()
      dht2.destroy()

test '`announce_peer` query gets ack response', (t) ->
  t.plan 5
  dht1 = new DHT(bootstrap: false)
  dht2 = new DHT(bootstrap: false)
  common.failOnWarningOrError t, dht1
  common.failOnWarningOrError t, dht2
  infoHash = common.randomId()
  dht1.listen ->
    port = dht1.address().port
    dht2._sendGetPeers '127.0.0.1:' + port, infoHash, (err, res1) ->
      t.error err
      t.deepEqual res1.id, dht1.nodeId
      t.ok Buffer.isBuffer(res1.token)
      dht2._sendAnnouncePeer '127.0.0.1:' + port, infoHash, 9999, res1.token, (err, res2) ->
        t.error err
        t.deepEqual res2.id, dht1.nodeId
        dht1.destroy()
        dht2.destroy()
