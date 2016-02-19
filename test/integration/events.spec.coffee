common = require('./../common')
DHT = require('../../')

describe 'Event tests', ->

  beforeEach ->
    jasmine.addMatchers(common.jasmineMatchers)

  it '`node` event fires for each added node (100x)', (done) ->
    dht = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht
    numNodes = 0

    dht.on 'node', ->
      numNodes += 1
      if numNodes == 100
        done()
    common.addRandomNodes dht, 100

  it '`node` event fires for each added node (10000x)', (done) ->
    dht = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht
    numNodes = 0

    dht.on 'node', ->
      numNodes += 1
      if numNodes == 10000
        done()
    common.addRandomNodes dht, 10000

  it '`listening` event fires', (done) ->
    dht = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht

    dht.listen ->

    dht.on 'listening', ->
      dht.destroy()
      done()

  it '`ready` event fires when bootstrap === false', (done) ->
    dht = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht

    dht.on 'ready', ->
      dht.destroy()
      done()

  it '`ready` event fires when there are K nodes', (done) ->
    # dht1 will simulate an existing node (with a populated routing table)
    dht1 = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht1

    dht1.on 'ready', ->
      common.addRandomNodes dht1, 3
      expect(dht1.nodes.count()).toBe 3

      dht1.listen ->
        port = dht1.address().port

        # dht2 will get all 3 nodes from dht1
        # and should also emit a `ready` event
        dht2 = new DHT(bootstrap: '127.0.0.1:' + port)
        common.failOnWarningOrError done, dht2

        dht2.on 'ready', ->
          # 5 nodes because dht1 also optimistically captured dht2's addr
          # and included it
          expect(dht1.nodes.count()).toBe 4
          dht1.destroy()
          dht2.destroy()
          done()
