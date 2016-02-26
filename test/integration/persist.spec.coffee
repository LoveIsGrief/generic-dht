r = require('require-root')('generic-dht')
common = r('test/common')
DHT = r('./')

describe 'Persistence tests', ->

  beforeEach ->
    jasmine.addMatchers(common.jasmineMatchers)


  it 'persist dht', (done) ->
    dht1 = new DHT(bootstrap: false)
    common.failOnWarningOrError done, dht1
    common.addRandomNodes dht1, DHT.K
    dht1.on 'ready', ->
      dht2 = new DHT(bootstrap: dht1.toArray())
      dht2.on 'ready', ->
        expect(dht2.toArray()).toDeepEqual dht1.toArray()
        dht1.destroy()
        dht2.destroy()
        done()

  # https://github.com/feross/bittorrent-dht/pull/36
  it 'bootstrap and listen to custom port', (done) ->
    dht = new DHT(bootstrap: [ '1.2.3.4:1000' ])
    common.failOnWarningOrError done, dht
    expect(dht.listening).toBeFalsy()
    dht.listen 12345
    expect(dht.listening).toBeFalsy()
    # bootstrapping should wait until next tick, so user has a chance to
    # listen to a custom port
    dht.on 'listening', ->
      expect(dht.listening).toBeTruthy()
      expect(dht.address().port).toBe 12345
    dht.on 'ready', ->
      dht.destroy()
      done()
