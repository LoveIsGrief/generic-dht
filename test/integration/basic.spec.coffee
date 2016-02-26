r = require('require-root')('generic-dht')
debug = require 'debug'
common = r('test/common')
DHT = r('./')

describe 'Basic DHT tests', ()->


  beforeEach ()->
    jasmine.addMatchers common.jasmineMatchers

  it 'should explicitly set nodeId', (done)->

    nodeId = common.randomId()
    dht = new DHT(
      nodeId: nodeId
      bootstrap: false)
    common.failOnWarningOrError done, dht
    expect(dht.nodeId).toDeepEqual nodeId
    done()

  it "should 'ping' query send and response", (done) ->

    dht1 = new DHT(bootstrap: false)
    dht2 = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht1
    common.failOnWarningOrError done, dht2
    dht1.listen ->
      dht2.sendQuery '127.0.0.1:' + dht1.address().port, (res) ->
        expect(res.id).toDeepEqual dht1.nodeId
        dht1.destroy()
        dht2.destroy()
        done()
      , ()->
        done.fail 'error for dht2'
      , 'ping'

  it 'should `find_node` query for exact match (with one in table)', (done) ->
    targetNodeId = common.randomId()
    dht1 = new DHT(bootstrap: false)
    dht2 = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht1
    common.failOnWarningOrError done, dht2
    dht1.addNode '255.255.255.255:6969', targetNodeId
    dht1.listen ->
      dht2.sendQuery '127.0.0.1:' + dht1.address().port,
        (res) ->
          expect(res.id).toDeepEqual dht1.nodeId
          resultingNodes = res.nodes.map (node) ->
            node.addr

          expectedNodes = [
            '255.255.255.255:6969'
            '127.0.0.1:' + dht2.address().port
          ]
          expect(resultingNodes).toDeepEqual expectedNodes
          dht1.destroy()
          dht2.destroy()
          done()
        , ()->
          done.fail 'error for dht2'
        , 'find_node', targetNodeId

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
      dht2.sendQuery '127.0.0.1:' + dht1.address().port,
        (res) ->
          expect(res.id).toDeepEqual dht1.nodeId
          expectedNodes =  [
            '1.1.1.1:6969'
            '10.10.10.10:6969'
            '127.0.0.1:' + dht2.address().port
            '255.255.255.255:6969'
          ]
          resultingNodes = res.nodes.map((node) ->
            node.addr
          ).sort()
          expect(resultingNodes).toDeepEqual expectedNodes
          dht1.destroy()
          dht2.destroy()
          done()
        , ()->
          done.fail 'error for dht2'
        , 'find_node', targetNodeId
