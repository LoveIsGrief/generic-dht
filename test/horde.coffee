test = require('tape')
parallel = require('run-parallel')
common = require('./common')
DHT = require('../')

###*
#  Initialize [numInstances] dhts, have one announce an infoHash, and another perform a
#  lookup. Times out after a while.
###

findPeers = (numInstances, t, cb) ->
  dhts = []
  timeoutId = setTimeout((->
    cb new Error('Timed out for ' + numInstances + ' instances')
  ), 20000)
  infoHash = common.randomId().toString('hex')
  i = 0
  while i < numInstances
    dht = new DHT(bootstrap: false)
    dhts.push dht
    common.failOnWarningOrError t, dht
    i++
  # wait until every dht is listening
  parallel dhts.map((dht) ->
    (cb) ->
      dht.listen ->
        cb null
  ), ->
    # add each other to routing tables
    makeFriends dhts
    if numInstances == 2
      # dhts[1] is the only one with the data, lookup() should find it in it's internal
      # table
      dhts[0].announce infoHash, 9998
      # wait until dhts[1] gets the announce from dhts[1]
      dhts[1].on 'announce', ->
        dhts[1].lookup infoHash
    else
      # lookup from other DHTs
      dhts[0].announce infoHash, 9998, ->
        dhts[1].lookup infoHash
  dhts[1].on 'peer', (addr, hash) ->
    t.equal hash, infoHash
    t.equal Number(addr.split(':')[1]), 9998
    clearTimeout timeoutId
    cb null, dhts

###*
# Add every dht address to the dht "before" it.
# This should guarantee that any dht can be located (with enough queries).
###

makeFriends = (dhts) ->
  len = dhts.length
  i = 0
  while i < len
    next = dhts[(i + 1) % len]
    dhts[i].addNode '127.0.0.1:' + next.address().port, next.nodeId
    i++

test 'announce+lookup with 2-10 DHTs', (t) ->
  from = 2
  to = 10
  numRunning = to - from + 1

  runAnnounceLookupTest = (numInstances) ->
    findPeers numInstances, t, (err, dhts) ->
      if err
        throw err
      dhts.forEach (dht) ->
        for infoHash of dht.tables
          table = dht.tables[infoHash]
          table.toArray().forEach (contact) ->
            t.ok contact.token, 'contact has token'
        process.nextTick ->
          dht.destroy ->
            if --numRunning == 0
              t.end()

  i = from
  while i <= to
    runAnnounceLookupTest i
    i++
