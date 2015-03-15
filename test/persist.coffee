common = require('./common')
DHT = require('../')
test = require('tape')
test 'persist dht', (t) ->
  t.plan 1
  dht1 = new DHT(bootstrap: false)
  common.failOnWarningOrError t, dht1
  common.addRandomNodes dht1, DHT.K
  dht1.on 'ready', ->
    dht2 = new DHT(bootstrap: dht1.toArray())
    dht2.on 'ready', ->
      t.deepEqual dht2.toArray(), dht1.toArray()
      dht1.destroy()
      dht2.destroy()
# https://github.com/feross/bittorrent-dht/pull/36
test 'bootstrap and listen to custom port', (t) ->
  t.plan 4
  dht = new DHT(bootstrap: [ '1.2.3.4:1000' ])
  common.failOnWarningOrError t, dht
  t.ok !dht.listening
  dht.listen 12345
  t.ok !dht.listening
  # bootstrapping should wait until next tick, so user has a chance to
  # listen to a custom port
  dht.on 'listening', ->
    t.ok dht.listening
    t.equal dht.address().port, 12345
  dht.on 'ready', ->
    dht.destroy()