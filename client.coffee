###*
# A DHT client implementation. The DHT is the main peer discovery layer for BitTorrent,
# which allows for trackerless torrents.
# @param {string|Buffer} opts
###

DHT = (opts) ->
  if !(@ instanceof DHT)
    return new DHT(opts)
  EventEmitter.call @
  if !debug.enabled
    @setMaxListeners 0
  if !opts
    opts = {}
  @nodeId = idToBuffer(opts.nodeId or hat(160))
  @ipv = opts.ipv or 4
  @_debug 'new DHT %s', idToHexString(@nodeId)
  @ready = false
  @listening = false
  @_binding = false
  @_destroyed = false
  @_port = null

  ###*
  # Query Handlers table
  # @type {Object} string -> function
  ###

  @queryHandler =
    ping: @_onPing
    find_node: @_onFindNode
    get_peers: @_onGetPeers
    announce_peer: @_onAnnouncePeer

  ###*
  # Routing table
  # @type {KBucket}
  ###

  @nodes = new KBucket(
    localNodeId: @nodeId
    numberOfNodesPerKBucket: K
    numberOfNodesToPing: MAX_CONCURRENCY)

  ###*
  # Cache of routing tables used during a lookup. Saved in this object so we can access
  # each node's unique token for announces later.
  # TODO: Clean up tables after 5 minutes.
  # @type {Object} infoHash:string -> KBucket
  ###

  @tables = {}

  ###*
  # Pending transactions (unresolved requests to peers)
  # @type {Object} addr:string -> array of pending transactions
  ###

  @transactions = {}

  ###*
  # Peer address data (tracker storage)
  # @type {Object} infoHash:string -> Object {index:Object, list:Array.<Buffer>}
  ###

  @peers = {}
  # Create socket and attach listeners
  @socket = module.exports.dgram.createSocket('udp' + @ipv)
  @socket.on 'message', @_onData.bind(@)
  @socket.on 'listening', @_onListening.bind(@)
  @socket.on 'error', ->
  # throw away errors
  @_rotateSecrets()
  @_rotateInterval = setInterval(@_rotateSecrets.bind(@), ROTATE_INTERVAL)
  @_rotateInterval.unref and @_rotateInterval.unref()
  process.nextTick =>
    if opts.bootstrap == false
      # Emit `ready` right away because the user does not want to bootstrap. Presumably,
      # the user will call addNode() to populate the routing table manually.
      @ready = true
      @emit 'ready'
    else if typeof opts.bootstrap == 'string'
      @_bootstrap [ opts.bootstrap ]
    else if Array.isArray(opts.bootstrap)
      @_bootstrap fromArray(opts.bootstrap)
    else
      # opts.bootstrap is undefined or true
      @_bootstrap BOOTSTRAP_NODES
  @on 'ready', ->
    @_debug 'emit ready'

###*
# Parse saved string
# @param  {Array.<Object>} nodes
# @return {Buffer}
###

fromArray = (nodes) ->
  nodes.forEach (node) ->
    if node.id
      node.id = idToBuffer(node.id)
  nodes

###*
# Convert "contacts" from the routing table into "compact node info" representation.
# @param  {Array.<Object>} contacts
# @return {Buffer}
###

convertToNodeInfo = (contacts) ->
  Buffer.concat contacts.map((contact) ->
    Buffer.concat [
      contact.id
      string2compact(contact.addr)
    ]
  )

###*
# Parse "compact node info" representation into "contacts".
# @param  {Buffer} nodeInfo
# @return {Array.<string>}  array of
###

parseNodeInfo = (nodeInfo) ->
  contacts = []
  try
    i = 0
    while i < nodeInfo.length
      contacts.push
        id: nodeInfo.slice(i, i + 20)
        addr: compact2string(nodeInfo.slice(i + 20, i + 26))
      i += 26
  catch err
    debug 'error parsing node info ' + nodeInfo
  contacts

###*
# Parse list of "compact addr info" into an array of addr "host:port" strings.
# @param  {Array.<Buffer>} list
# @return {Array.<string>}
###

parsePeerInfo = (list) ->
  try
    return list.map(compact2string)
  catch err
    debug 'error parsing peer info ' + list
    return []

###*
# Ensure a transacation id is a 16-bit buffer, so it can be sent on the wire as
# the transaction id ("t" field).
# @param  {number|Buffer} transactionId
# @return {Buffer}
###

transactionIdToBuffer = (transactionId) ->
  if Buffer.isBuffer(transactionId)
    transactionId
  else
    buf = new Buffer(2)
    buf.writeUInt16BE transactionId, 0
    buf

###*
# Ensure info hash or node id is a Buffer.
# @param  {string|Buffer} id
# @return {Buffer}
###

idToBuffer = (id) ->
  if Buffer.isBuffer(id)
    id
  else
    new Buffer(id, 'hex')

###*
# Ensure info hash or node id is a hex string.
# @param  {string|Buffer} id
# @return {Buffer}
###

idToHexString = (id) ->
  if Buffer.isBuffer(id)
    id.toString 'hex'
  else
    id

# Return sha1 hash **as a buffer**

sha1 = (buf) ->
  crypto.createHash('sha1').update(buf).digest()

module.exports = DHT
module.exports.dgram = require('dgram')
# allow override for chrome apps (chrome-dgram)
addrToIPPort = require('addr-to-ip-port')
bencode = require('bencode')
bufferEqual = require('buffer-equal')
compact2string = require('compact2string')
crypto = require('crypto')
debug = require('debug')('bittorrent-dht')
dns = require('dns')
EventEmitter = require('events').EventEmitter
hat = require('hat')
inherits = require('inherits')
isIP = require('is-ip')
KBucket = require('k-bucket')
once = require('once')
os = require('os')
parallel = require('run-parallel')
string2compact = require('string2compact')
BOOTSTRAP_NODES = [
  'router.bittorrent.com:6881'
  'router.utorrent.com:6881'
  'dht.transmissionbt.com:6881'
]
BOOTSTRAP_TIMEOUT = 10000
K = module.exports.K = 20
# number of nodes per bucket
MAX_CONCURRENCY = 6
# α from Kademlia paper
ROTATE_INTERVAL = 5 * 60 * 1000
# rotate secrets every 5 minutes
SECRET_ENTROPY = 160
# entropy of token secrets
SEND_TIMEOUT = 2000
MESSAGE_TYPE = module.exports.MESSAGE_TYPE =
  QUERY: 'q'
  RESPONSE: 'r'
  ERROR: 'e'
ERROR_TYPE = module.exports.ERROR_TYPE =
  GENERIC: 201
  SERVER: 202
  PROTOCOL: 203
  METHOD_UNKNOWN: 204
LOCAL_HOSTS =
  4: []
  6: []
interfaces = os.networkInterfaces()
for i of interfaces
  j = 0
  while j < interfaces[i].length
    face = interfaces[i][j]
    if face.family == 'IPv4'
      LOCAL_HOSTS[4].push face.address
    if face.family == 'IPv6'
      LOCAL_HOSTS[6].push face.address
    j++
inherits DHT, EventEmitter

###*
# Start listening for UDP messages on given port.
# @param  {number} port
# @param  {string} address
# @param  {function=} onlistening added as handler for listening event
###

DHT::listen = (port, address, onlistening) ->
  if typeof port == 'string'
    onlistening = address
    address = port
    port = undefined
  if typeof port == 'function'
    onlistening = port
    port = undefined
    address = undefined
  if typeof address == 'function'
    onlistening = address
    address = undefined
  if onlistening
    @once 'listening', onlistening
  return if @_destroyed or @_binding or @listening
  @_binding = true
  @_debug 'listen %s', port
  @socket.bind port, address

###*
# Called when DHT is listening for UDP messages.
###

DHT::_onListening = ->
  @_binding = false
  @listening = true
  @_port = @socket.address().port
  @_debug 'emit listening %s', @_port
  @emit 'listening'

DHT::address = ->
  @socket.address()

###*
# Announce that the peer, controlling the querying node, is downloading a torrent on a
# port.
# @param  {string|Buffer} infoHash
# @param  {number} port
# @param  {function=} cb
###

DHT::announce = (infoHash, port, cb) ->

  onClosest = (err, closest) =>
    if err
      return cb(err)
    closest.forEach (contact) =>
      @_sendAnnouncePeer contact.addr, infoHash, port, contact.token
    @_debug 'announce end %s %s', infoHash, port
    cb null

  if !cb

    cb = ->

  if @_destroyed
    return cb(new Error('dht is destroyed'))
  @_debug 'announce %s %s', infoHash, port
  infoHashHex = idToHexString(infoHash)
  # TODO: it would be nice to not use a table when a lookup is in progress
  table = @tables[infoHashHex]
  if table
    onClosest null, table.closest({ id: infoHash }, K)
  else
    @lookup infoHash, onClosest

###*
# Destroy and cleanup the DHT.
# @param  {function=} cb
###

DHT::destroy = (cb) ->
  if !cb

    cb = ->

  cb = once(cb)
  if @_destroyed
    return cb(new Error('dht is destroyed'))
  if @_binding
    return @once('listening', @destroy.bind(@, cb))
  @_debug 'destroy'
  @_destroyed = true
  @listening = false
  # garbage collect large data structures
  @nodes = null
  @tables = null
  @transactions = null
  @peers = null
  clearTimeout @_bootstrapTimeout
  clearInterval @_rotateInterval
  @socket.on 'close', cb
  try
    @socket.close()
  catch err
    # ignore error, socket was either already closed / not yet bound
    cb null

###*
# Add a DHT node to the routing table.
# @param {string} addr
# @param {string|Buffer} nodeId
# @param {string=} from addr
###

DHT::addNode = (addr, nodeId, from) ->
  return if @_destroyed
  nodeId = idToBuffer(nodeId)
  return if @_addrIsSelf(addr)
    # @_debug('skipping adding %s since that is us!', addr)
  contact =
    id: nodeId
    addr: addr
  @nodes.add contact
  # TODO: only emit this event for new nodes
  @emit 'node', addr, nodeId, from
  @_debug 'addNode %s %s discovered from %s', idToHexString(nodeId), addr, from

###*
# Remove a DHT node from the routing table.
# @param  {string|Buffer} nodeId
###

DHT::removeNode = (nodeId) ->
  return if @_destroyed
  contact = @nodes.get(idToBuffer(nodeId))
  if contact
    @_debug 'removeNode %s %s', contact.nodeId, contact.addr
    @nodes.remove contact

###*
# Store a peer in the DHT. Called when a peer sends a `announce_peer` message.
# @param {string} addr
# @param {Buffer|string} infoHash
###

DHT::_addPeer = (addr, infoHash) ->
  return if @_destroyed
  infoHash = idToHexString(infoHash)
  peers = @peers[infoHash]
  if !peers
    peers = @peers[infoHash] =
      index: {}
      list: []
  if !peers.index[addr]
    peers.index[addr] = true
    peers.list.push string2compact(addr)
    @_debug 'addPeer %s %s', addr, infoHash
    @emit 'announce', addr, infoHash

###*
# Remove a peer from the DHT.
# @param  {string} addr
# @param  {Buffer|string} infoHash
###

DHT::removePeer = (addr, infoHash) ->
  return if @_destroyed
  infoHash = idToHexString(infoHash)
  peers = @peers[infoHash]
  if peers and peers.index[addr]
    peers.index[addr] = null
    compactPeerInfo = string2compact(addr)
    peers.list.some (peer, index) ->
      if bufferEqual(peer, compactPeerInfo)
        peers.list.splice index, 1
        @_debug 'removePeer %s %s', addr, infoHash
        return true
        # abort early

###*
# Join the DHT network. To join initially, connect to known nodes (either public
# bootstrap nodes, or known nodes from a previous run of bittorrent-client).
# @param  {Array.<string|Object>} nodes
###

DHT::_bootstrap = (nodes) ->
  @_debug 'bootstrap with %s', JSON.stringify(nodes)
  contacts = nodes.map((obj) ->
    if typeof obj == 'string'
      { addr: obj }
    else
      obj
  )
  @_resolveContacts contacts, (err, contacts)=>

    lookup = =>
      @lookup @nodeId, {
        findNode: true
        addrs: if addrs.length then addrs else null
      }, (err) =>
        if err
          @_debug 'lookup error %s during bootstrap', err.message
        # emit `ready` once the recursive lookup for our own node ID is finished
        # (successful or not), so that later get_peer lookups will have a good shot at
        # succeeding.
        if !@ready
          @ready = true
          @emit 'ready'

    if err
      return @emit('error', err)
    # add all non-bootstrap nodes to routing table
    contacts.filter((contact) ->
      ! !contact.id
    ).forEach (contact) =>
      @addNode contact.addr, contact.id, contact.from
    # get addresses of bootstrap nodes
    addrs = contacts.filter((contact) ->
      !contact.id
    ).map((contact) ->
      contact.addr
    )
    lookup()
    # TODO: keep retrying after one failure
    @_bootstrapTimeout = setTimeout((=>
      return if @_destroyed
      # If 0 nodes are in the table after a timeout, retry with bootstrap nodes
      if @nodes.count() == 0
        @_debug 'No DHT bootstrap nodes replied, retry'
        lookup()
    ), BOOTSTRAP_TIMEOUT)
    @_bootstrapTimeout.unref and @_bootstrapTimeout.unref()

###*
# Resolve the DNS for nodes whose hostname is a domain name (often the case for
# bootstrap nodes).
# @param  {Array.<Object>} contacts array of contact objects with domain addresses
# @param  {function} done
###

DHT::_resolveContacts = (contacts, done) ->
  tasks = contacts.map((contact) =>
    (cb) ->
      addrData = addrToIPPort(contact.addr)
      if isIP(addrData[0])
        cb null, contact
      else
        dns.lookup addrData[0], @ipv, (err, host) ->
          if err
            return cb(null, null)
          contact.addr = host + ':' + addrData[1]
          cb null, contact
  )
  parallel tasks, (err, contacts) ->
    if err
      return done(err)
    # filter out hosts that don't resolve
    contacts = contacts.filter((contact) ->
      ! !contact
    )
    done null, contacts

###*
# Perform a recurive node lookup for the given nodeId. If isFindNode is true, then
# `find_node` will be sent to each peer instead of `get_peers`.
# @param {Buffer|string} id node id or info hash
# @param {Object=} opts
# @param {boolean} opts.findNode
# @param {Array.<string>} opts.addrs
# @param {function} cb called with K closest nodes
###

DHT::lookup = (id, opts, cb) ->

  add = (contact) =>
    return if @_addrIsSelf(contact.addr)
    if contact.token
      tokenful.add contact
    table.add contact

  query = (addr) =>
    pending += 1
    queried[addr] = true
    if opts.findNode
      @_sendFindNode addr, id, onResponse.bind(null, addr)
    else
      @_sendGetPeers addr, id, onResponse.bind(null, addr)

  queryClosest = =>
    @nodes.closest({ id: id }, K).forEach (contact) ->
      query contact.addr

  # Note: `_sendFindNode` and `_sendGetPeers` will insert newly discovered nodes into
  # the routing table, so that's not done here.

  onResponse = (addr, err, res) =>
    if @_destroyed
      return cb(new Error('dht is destroyed'))
    pending -= 1
    nodeId = res and res.id
    nodeIdHex = idToHexString(nodeId)
    # ignore errors - they are just timeouts
    if err
      @_debug 'got lookup error: %s', err.message
    else
      @_debug 'got lookup response from %s', nodeIdHex
      # add node that sent this response
      contact = table.get(nodeId) or
        id: nodeId
        addr: addr
      contact.token = res and res.token
      add contact
      # add nodes to this routing table for this lookup
      if res and res.nodes
        res.nodes.forEach (contact) ->
          add contact
    # find closest unqueried nodes
    candidates = table.closest({ id: id }, K).filter((contact) ->
      !queried[contact.addr]
    )
    while pending < MAX_CONCURRENCY and candidates.length
      # query as many candidates as our concurrency limit will allow
      query candidates.pop().addr
    if pending == 0 and candidates.length == 0
      # recursive lookup should terminate because there are no closer nodes to find
      @_debug 'terminating lookup %s %s', (if opts.findNode then '(find_node)' else '(get_peers)'), idHex
      closest = (if opts.findNode then table else tokenful).closest({ id: id }, K)
      @_debug 'K closest nodes are:'
      closest.forEach (contact) =>
        @_debug '  ' + contact.addr + ' ' + idToHexString(contact.id)
      cb null, closest

  id = idToBuffer(id)
  if typeof opts == 'function'
    cb = opts
    opts = {}
  if !opts
    opts = {}
  if !cb

    cb = ->

  cb = once(cb)
  if @_destroyed
    return cb(new Error('dht is destroyed'))
  if !@listening
    return @listen(@lookup.bind(@, id, opts, cb))
  idHex = idToHexString(id)
  @_debug 'lookup %s %s', (if opts.findNode then '(find_node)' else '(get_peers)'), idHex
  # Return local peers, if we have any in our table
  peers = @peers[idHex] and @peers[idHex]
  if peers
    peers = parsePeerInfo(peers.list)
    peers.forEach (peerAddr) =>
      @_debug 'emit peer %s %s from %s', peerAddr, idHex, 'local'
      @emit 'peer', peerAddr, idHex, 'local'
  table = new KBucket(
    localNodeId: id
    numberOfNodesPerKBucket: K
    numberOfNodesToPing: MAX_CONCURRENCY)
  # NOT the same table as the one used for the lookup, as that table may have nodes without tokens
  if !@tables[idHex]
    @tables[idHex] = new KBucket(
      localNodeId: id
      numberOfNodesPerKBucket: K
      numberOfNodesToPing: MAX_CONCURRENCY)
  tokenful = @tables[idHex]
  queried = {}
  pending = 0
  # pending queries
  if opts.addrs
    # kick off lookup with explicitly passed nodes (usually, bootstrap servers)
    opts.addrs.forEach query
  else
    # kick off lookup with nodes in the main table
    queryClosest()

###*
# Called when another node sends a UDP message
# @param {Buffer} data
# @param {Object} rinfo
###

DHT::_onData = (data, rinfo) ->
  addr = rinfo.address + ':' + rinfo.port
  message = undefined
  errMessage = undefined
  try
    message = bencode.decode(data)
    if !message
      throw new Error('message is empty')
  catch err
    errMessage = err.message + ' from ' + addr + ' (' + data + ')'
    @_debug errMessage
    @emit 'warning', new Error(errMessage)
  type = message.y and message.y.toString()
  if type != MESSAGE_TYPE.QUERY and type != MESSAGE_TYPE.RESPONSE and type != MESSAGE_TYPE.ERROR
    errMessage = 'unknown message type ' + type + ' from ' + addr
    @_debug errMessage
    @emit 'warning', new Error(errMessage)
  # @_debug('got data %s from %s', JSON.stringify(message), addr)
  # Attempt to add every (valid) node that we see to the routing table.
  # TODO: If they node is already in the table, just update the "last heard from" time
  nodeId = message.r and message.r.id or message.a and message.a.id
  if nodeId
    # TODO: verify that this a valid length for a nodeId
    # @_debug('adding (potentially) new node %s %s', idToHexString(nodeId), addr)
    @addNode addr, nodeId, addr
  if type == MESSAGE_TYPE.QUERY
    @_onQuery addr, message
  else if type == MESSAGE_TYPE.RESPONSE or type == MESSAGE_TYPE.ERROR
    @_onResponseOrError addr, type, message

###*
# Called when another node sends a query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onQuery = (addr, message) ->
  query = message.q.toString()
  if typeof @queryHandler[query] == 'function'
    @queryHandler[query].call @, addr, message
  else
    errMessage = 'unexpected query type'
    @_debug errMessage
    @_sendError addr, message.t, ERROR_TYPE.METHOD_UNKNOWN, errMessage

###*
# Called when another node sends a response or error.
# @param  {string} addr
# @param  {string} type
# @param  {Object} message
###

DHT::_onResponseOrError = (addr, type, message) ->
  transactionId = Buffer.isBuffer(message.t) and message.t.length == 2 and message.t.readUInt16BE(0)
  transaction = @transactions and @transactions[addr] and @transactions[addr][transactionId]
  err = null
  if type == MESSAGE_TYPE.ERROR
    err = new Error(if Array.isArray(message.e) then message.e.join(' ') else undefined)
  if !transaction or !transaction.cb
    # unexpected message!
    if err
      errMessage = 'got unexpected error from ' + addr + ' ' + err.message
      @_debug errMessage
      @emit 'warning', new Error(errMessage)
    else
      @_debug 'got unexpected message from ' + addr + ' ' + JSON.stringify(message)
      @emit 'warning', new Error(errMessage)
    return
  transaction.cb err, message.r

###*
# Send a UDP message to the given addr.
# @param  {string} addr
# @param  {Object} message
# @param  {function=} cb  called once message has been sent
###

DHT::_send = (addr, message, cb) ->
  if !@listening
    return @listen(@_send.bind(@, addr, message, cb))
  if !cb

    cb = ->

  addrData = addrToIPPort(addr)
  host = addrData[0]
  port = addrData[1]
  return if !(port > 0 and port < 65535)
  # @_debug('send %s to %s', JSON.stringify(message), addr)
  message = bencode.encode(message)
  @socket.send message, 0, message.length, port, host, cb

DHT::_query = (data, addr, cb) ->
  if !data.a
    data.a = {}
  if !data.a.id
    data.a.id = @nodeId
  transactionId = @_getTransactionId(addr, cb)
  message =
    t: transactionIdToBuffer(transactionId)
    y: MESSAGE_TYPE.QUERY
    q: data.q
    a: data.a
  if data.q == 'find_node'
    @_debug 'sent find_node %s to %s', data.a.target.toString('hex'), addr
  else if data.q == 'get_peers'
    @_debug 'sent get_peers %s to %s', data.a.info_hash.toString('hex'), addr
  @_send addr, message

###*
# Send "ping" query to given addr.
# @param {string} addr
# @param {function} cb called with response
###

DHT::_sendPing = (addr, cb) ->
  @_query { q: 'ping' }, addr, cb

###*
# Called when another node sends a "ping" query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onPing = (addr, message) ->
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r: id: @nodeId
  @_debug 'got ping from %s', addr
  @_send addr, res

###*
# Send "find_node" query to given addr.
# @param {string} addr
# @param {Buffer} nodeId
# @param {function} cb called with response
###

DHT::_sendFindNode = (addr, nodeId, cb) ->
  data =
    q: 'find_node'
    a:
      id: @nodeId
      target: nodeId

  onResponse = (err, res) =>
    if err
      return cb(err)
    if res.nodes
      res.nodes = parseNodeInfo(res.nodes)
      res.nodes.forEach (node) =>
        @addNode node.addr, node.id, addr
    cb null, res

  @_query data, addr, onResponse

###*
# Called when another node sends a "find_node" query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onFindNode = (addr, message) ->
  nodeId = message.a and message.a.target
  if !nodeId
    errMessage = '`find_node` missing required `a.target` field'
    @_debug errMessage
    @_sendError addr, message.t, ERROR_TYPE.PROTOCOL, errMessage
  @_debug 'got find_node %s from %s', idToHexString(nodeId), addr
  # Convert nodes to "compact node info" representation
  nodes = convertToNodeInfo(@nodes.closest({ id: nodeId }, K))
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r:
      id: @nodeId
      nodes: nodes
  @_send addr, res

###*
# Send "get_peers" query to given addr.
# @param {string} addr
# @param {Buffer|string} infoHash
# @param {function} cb called with response
###

DHT::_sendGetPeers = (addr, infoHash, cb) ->

  onResponse = (err, res) =>
    if err
      return cb(err)
    if res.nodes
      res.nodes = parseNodeInfo(res.nodes)
      res.nodes.forEach (node) =>
        @addNode node.addr, node.id, addr
    if res.values
      res.values = parsePeerInfo(res.values)
      res.values.forEach (peerAddr) =>
        @_debug 'emit peer %s %s from %s', peerAddr, infoHashHex, addr
        @emit 'peer', peerAddr, infoHashHex, addr
    cb null, res

  infoHash = idToBuffer(infoHash)
  infoHashHex = idToHexString(infoHash)
  data =
    q: 'get_peers'
    a:
      id: @nodeId
      info_hash: infoHash
  @_query data, addr, onResponse

###*
# Called when another node sends a "get_peers" query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onGetPeers = (addr, message) ->
  addrData = addrToIPPort(addr)
  infoHash = message.a and message.a.info_hash
  if !infoHash
    errMessage = '`get_peers` missing required `a.info_hash` field'
    @_debug errMessage
    @_sendError addr, message.t, ERROR_TYPE.PROTOCOL, errMessage
  infoHashHex = idToHexString(infoHash)
  @_debug 'got get_peers %s from %s', infoHashHex, addr
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r:
      id: @nodeId
      token: @_generateToken(addrData[0])
  peers = @peers[infoHashHex] and @peers[infoHashHex].list
  if peers
    # We know of peers for the target info hash. Peers are stored as an array of
    # compact peer info, so return it as-is.
    res.r.values = peers
  else
    # No peers, so return the K closest nodes instead. Convert nodes to "compact node
    # info" representation
    res.r.nodes = convertToNodeInfo(@nodes.closest({ id: infoHash }, K))
  @_send addr, res

###*
# Send "announce_peer" query to given host and port.
# @param {string} addr
# @param {Buffer|string} infoHash
# @param {number} port
# @param {Buffer} token
# @param {function=} cb called with response
###

DHT::_sendAnnouncePeer = (addr, infoHash, port, token, cb) ->
  infoHash = idToBuffer(infoHash)
  if !cb

    cb = ->

  data =
    q: 'announce_peer'
    a:
      id: @nodeId
      info_hash: infoHash
      port: port
      token: token
      implied_port: 0
  @_query data, addr, cb

###*
# Called when another node sends a "announce_peer" query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onAnnouncePeer = (addr, message) ->
  errMessage = undefined
  addrData = addrToIPPort(addr)
  infoHash = idToHexString(message.a and message.a.info_hash)
  if !infoHash
    errMessage = '`announce_peer` missing required `a.info_hash` field'
    @_debug errMessage
    @_sendError addr, message.t, ERROR_TYPE.PROTOCOL, errMessage
  token = message.a and message.a.token
  if !@_isValidToken(token, addrData[0])
    errMessage = 'cannot `announce_peer` with bad token'
    @_sendError addr, message.t, ERROR_TYPE.PROTOCOL, errMessage
  port = if message.a.implied_port != 0 then addrData[1] else message.a.port
  # use port in `announce_peer` message
  @_debug 'got announce_peer %s %s from %s with token %s', idToHexString(infoHash), port, addr, idToHexString(token)
  @_addPeer addrData[0] + ':' + port, infoHash
  # send acknowledgement
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r: id: @nodeId
  @_send addr, res

###*
# Send an error to given host and port.
# @param  {string} addr
# @param  {Buffer|number} transactionId
# @param  {number} code
# @param  {string} errMessage
###

DHT::_sendError = (addr, transactionId, code, errMessage) ->
  if transactionId and !Buffer.isBuffer(transactionId)
    transactionId = transactionIdToBuffer(transactionId)
  message =
    y: MESSAGE_TYPE.ERROR
    e: [
      code
      errMessage
    ]
  if transactionId
    message.t = transactionId
  @_debug 'sent error %s to %s', JSON.stringify(message), addr
  @_send addr, message

###*
# Get a transaction id, and (optionally) set a function to be called
# @param  {string}   addr
# @param  {function} fn
###

DHT::_getTransactionId = (addr, fn) ->

  onTimeout = ->
    reqs[transactionId] = null
    fn new Error('query timed out')

  onResponse = (err, res) ->
    clearTimeout reqs[transactionId].timeout
    reqs[transactionId] = null
    fn err, res

  fn = once(fn)
  reqs = @transactions[addr]
  if !reqs
    reqs = @transactions[addr] = {}
    reqs.nextTransactionId = 0
  transactionId = reqs.nextTransactionId
  reqs.nextTransactionId += 1
  reqs[transactionId] =
    cb: onResponse
    timeout: setTimeout(onTimeout, SEND_TIMEOUT)
  transactionId

###*
# Generate token (for response to `get_peers` query). Tokens are the SHA1 hash of
# the IP address concatenated onto a secret that changes every five minutes. Tokens up
# to ten minutes old are accepted.
# @param {string} host
# @param {Buffer=} secret force token to use this secret, otherwise use current one
# @return {Buffer}
###

DHT::_generateToken = (host, secret) ->
  if !secret
    secret = @secrets[0]
  sha1 Buffer.concat([
    new Buffer(host, 'utf8')
    secret
  ])

###*
# Checks if a token is valid for a given node's IP address.
#
# @param  {Buffer} token
# @param  {string} host
# @return {boolean}
###

DHT::_isValidToken = (token, host) ->
  validToken0 = @_generateToken(host, @secrets[0])
  validToken1 = @_generateToken(host, @secrets[1])
  bufferEqual(token, validToken0) or bufferEqual(token, validToken1)

###*
# Rotate secrets. Secrets are rotated every 5 minutes and tokens up to ten minutes
# old are accepted.
###

DHT::_rotateSecrets = ->
  # Initialize secrets array
  # @secrets[0] is the current secret, used to generate new tokens
  # @secrets[1] is the last secret, which is still accepted

  createSecret = ->
    new Buffer(hat(SECRET_ENTROPY), 'hex')

  if !@secrets
    @secrets = [
      createSecret()
      createSecret()
    ]
    return
  @secrets[1] = @secrets[0]
  @secrets[0] = createSecret()

###*
# Get a string that can be used to initialize and bootstrap the DHT in the
# future.
# @return {Array.<Object>}
###

DHT::toArray = ->
  nodes = @nodes.toArray().map((contact) ->
    # to remove properties added by k-bucket, like `distance`, etc.
    {
      id: contact.id.toString('hex')
      addr: contact.addr
    }
  )
  nodes

DHT::_addrIsSelf = (addr) ->
  @_port and LOCAL_HOSTS[@ipv].some((host) ->
    host + ':' + @_port == addr
  )

DHT::_debug = ->
  args = [].slice.call(arguments)
  args[0] = '[' + idToHexString(@nodeId).substring(0, 7) + '] ' + args[0]
  debug.apply null, args
