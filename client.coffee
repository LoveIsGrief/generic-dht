###*
# A DHT client implementation. The DHT is the main peer discovery layer for BitTorrent,
# which allows for trackerless torrents.
# @param {string|Buffer} opts
###

DHT = (opts) ->
  self = this
  if !(self instanceof DHT)
    return new DHT(opts)
  EventEmitter.call self
  if !debug.enabled
    self.setMaxListeners 0
  if !opts
    opts = {}
  self.nodeId = idToBuffer(opts.nodeId or hat(160))
  self.ipv = opts.ipv or 4
  self._debug 'new DHT %s', idToHexString(self.nodeId)
  self.ready = false
  self.listening = false
  self._binding = false
  self._destroyed = false
  self._port = null

  ###*
  # Query Handlers table
  # @type {Object} string -> function
  ###

  self.queryHandler =
    ping: self._onPing
    find_node: self._onFindNode
    get_peers: self._onGetPeers
    announce_peer: self._onAnnouncePeer

  ###*
  # Routing table
  # @type {KBucket}
  ###

  self.nodes = new KBucket(
    localNodeId: self.nodeId
    numberOfNodesPerKBucket: K
    numberOfNodesToPing: MAX_CONCURRENCY)

  ###*
  # Cache of routing tables used during a lookup. Saved in this object so we can access
  # each node's unique token for announces later.
  # TODO: Clean up tables after 5 minutes.
  # @type {Object} infoHash:string -> KBucket
  ###

  self.tables = {}

  ###*
  # Pending transactions (unresolved requests to peers)
  # @type {Object} addr:string -> array of pending transactions
  ###

  self.transactions = {}

  ###*
  # Peer address data (tracker storage)
  # @type {Object} infoHash:string -> Object {index:Object, list:Array.<Buffer>}
  ###

  self.peers = {}
  # Create socket and attach listeners
  self.socket = module.exports.dgram.createSocket('udp' + self.ipv)
  self.socket.on 'message', self._onData.bind(self)
  self.socket.on 'listening', self._onListening.bind(self)
  self.socket.on 'error', ->
  # throw away errors
  self._rotateSecrets()
  self._rotateInterval = setInterval(self._rotateSecrets.bind(self), ROTATE_INTERVAL)
  self._rotateInterval.unref and self._rotateInterval.unref()
  process.nextTick ->
    if opts.bootstrap == false
      # Emit `ready` right away because the user does not want to bootstrap. Presumably,
      # the user will call addNode() to populate the routing table manually.
      self.ready = true
      self.emit 'ready'
    else if typeof opts.bootstrap == 'string'
      self._bootstrap [ opts.bootstrap ]
    else if Array.isArray(opts.bootstrap)
      self._bootstrap fromArray(opts.bootstrap)
    else
      # opts.bootstrap is undefined or true
      self._bootstrap BOOTSTRAP_NODES
    return
  self.on 'ready', ->
    self._debug 'emit ready'
    return
  return

###*
# Parse saved string
# @param  {Array.<Object>} nodes
# @return {Buffer}
###

fromArray = (nodes) ->
  nodes.forEach (node) ->
    if node.id
      node.id = idToBuffer(node.id)
    return
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
  return

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
  self = this
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
    self.once 'listening', onlistening
  if self._destroyed or self._binding or self.listening
    return
  self._binding = true
  self._debug 'listen %s', port
  self.socket.bind port, address
  return

###*
# Called when DHT is listening for UDP messages.
###

DHT::_onListening = ->
  self = this
  self._binding = false
  self.listening = true
  self._port = self.socket.address().port
  self._debug 'emit listening %s', self._port
  self.emit 'listening'
  return

DHT::address = ->
  self = this
  self.socket.address()

###*
# Announce that the peer, controlling the querying node, is downloading a torrent on a
# port.
# @param  {string|Buffer} infoHash
# @param  {number} port
# @param  {function=} cb
###

DHT::announce = (infoHash, port, cb) ->
  self = this

  onClosest = (err, closest) ->
    if err
      return cb(err)
    closest.forEach (contact) ->
      self._sendAnnouncePeer contact.addr, infoHash, port, contact.token
      return
    self._debug 'announce end %s %s', infoHash, port
    cb null
    return

  if !cb

    cb = ->

  if self._destroyed
    return cb(new Error('dht is destroyed'))
  self._debug 'announce %s %s', infoHash, port
  infoHashHex = idToHexString(infoHash)
  # TODO: it would be nice to not use a table when a lookup is in progress
  table = self.tables[infoHashHex]
  if table
    onClosest null, table.closest({ id: infoHash }, K)
  else
    self.lookup infoHash, onClosest
  return

###*
# Destroy and cleanup the DHT.
# @param  {function=} cb
###

DHT::destroy = (cb) ->
  self = this
  if !cb

    cb = ->

  cb = once(cb)
  if self._destroyed
    return cb(new Error('dht is destroyed'))
  if self._binding
    return self.once('listening', self.destroy.bind(self, cb))
  self._debug 'destroy'
  self._destroyed = true
  self.listening = false
  # garbage collect large data structures
  self.nodes = null
  self.tables = null
  self.transactions = null
  self.peers = null
  clearTimeout self._bootstrapTimeout
  clearInterval self._rotateInterval
  self.socket.on 'close', cb
  try
    self.socket.close()
  catch err
    # ignore error, socket was either already closed / not yet bound
    cb null
  return

###*
# Add a DHT node to the routing table.
# @param {string} addr
# @param {string|Buffer} nodeId
# @param {string=} from addr
###

DHT::addNode = (addr, nodeId, from) ->
  self = this
  if self._destroyed
    return
  nodeId = idToBuffer(nodeId)
  if self._addrIsSelf(addr)
    # self._debug('skipping adding %s since that is us!', addr)
    return
  contact =
    id: nodeId
    addr: addr
  self.nodes.add contact
  # TODO: only emit this event for new nodes
  self.emit 'node', addr, nodeId, from
  self._debug 'addNode %s %s discovered from %s', idToHexString(nodeId), addr, from
  return

###*
# Remove a DHT node from the routing table.
# @param  {string|Buffer} nodeId
###

DHT::removeNode = (nodeId) ->
  self = this
  if self._destroyed
    return
  contact = self.nodes.get(idToBuffer(nodeId))
  if contact
    self._debug 'removeNode %s %s', contact.nodeId, contact.addr
    self.nodes.remove contact
  return

###*
# Store a peer in the DHT. Called when a peer sends a `announce_peer` message.
# @param {string} addr
# @param {Buffer|string} infoHash
###

DHT::_addPeer = (addr, infoHash) ->
  self = this
  if self._destroyed
    return
  infoHash = idToHexString(infoHash)
  peers = self.peers[infoHash]
  if !peers
    peers = self.peers[infoHash] =
      index: {}
      list: []
  if !peers.index[addr]
    peers.index[addr] = true
    peers.list.push string2compact(addr)
    self._debug 'addPeer %s %s', addr, infoHash
    self.emit 'announce', addr, infoHash
  return

###*
# Remove a peer from the DHT.
# @param  {string} addr
# @param  {Buffer|string} infoHash
###

DHT::removePeer = (addr, infoHash) ->
  self = this
  if self._destroyed
    return
  infoHash = idToHexString(infoHash)
  peers = self.peers[infoHash]
  if peers and peers.index[addr]
    peers.index[addr] = null
    compactPeerInfo = string2compact(addr)
    peers.list.some (peer, index) ->
      if bufferEqual(peer, compactPeerInfo)
        peers.list.splice index, 1
        self._debug 'removePeer %s %s', addr, infoHash
        return true
        # abort early
      return
  return

###*
# Join the DHT network. To join initially, connect to known nodes (either public
# bootstrap nodes, or known nodes from a previous run of bittorrent-client).
# @param  {Array.<string|Object>} nodes
###

DHT::_bootstrap = (nodes) ->
  self = this
  self._debug 'bootstrap with %s', JSON.stringify(nodes)
  contacts = nodes.map((obj) ->
    if typeof obj == 'string'
      { addr: obj }
    else
      obj
  )
  self._resolveContacts contacts, (err, contacts) ->

    lookup = ->
      self.lookup self.nodeId, {
        findNode: true
        addrs: if addrs.length then addrs else null
      }, (err) ->
        if err
          self._debug 'lookup error %s during bootstrap', err.message
        # emit `ready` once the recursive lookup for our own node ID is finished
        # (successful or not), so that later get_peer lookups will have a good shot at
        # succeeding.
        if !self.ready
          self.ready = true
          self.emit 'ready'
        return
      return

    if err
      return self.emit('error', err)
    # add all non-bootstrap nodes to routing table
    contacts.filter((contact) ->
      ! !contact.id
    ).forEach (contact) ->
      self.addNode contact.addr, contact.id, contact.from
      return
    # get addresses of bootstrap nodes
    addrs = contacts.filter((contact) ->
      !contact.id
    ).map((contact) ->
      contact.addr
    )
    lookup()
    # TODO: keep retrying after one failure
    self._bootstrapTimeout = setTimeout((->
      if self._destroyed
        return
      # If 0 nodes are in the table after a timeout, retry with bootstrap nodes
      if self.nodes.count() == 0
        self._debug 'No DHT bootstrap nodes replied, retry'
        lookup()
      return
    ), BOOTSTRAP_TIMEOUT)
    self._bootstrapTimeout.unref and self._bootstrapTimeout.unref()
    return
  return

###*
# Resolve the DNS for nodes whose hostname is a domain name (often the case for
# bootstrap nodes).
# @param  {Array.<Object>} contacts array of contact objects with domain addresses
# @param  {function} done
###

DHT::_resolveContacts = (contacts, done) ->
  self = this
  tasks = contacts.map((contact) ->
    (cb) ->
      addrData = addrToIPPort(contact.addr)
      if isIP(addrData[0])
        cb null, contact
      else
        dns.lookup addrData[0], self.ipv, (err, host) ->
          if err
            return cb(null, null)
          contact.addr = host + ':' + addrData[1]
          cb null, contact
          return
      return
  )
  parallel tasks, (err, contacts) ->
    if err
      return done(err)
    # filter out hosts that don't resolve
    contacts = contacts.filter((contact) ->
      ! !contact
    )
    done null, contacts
    return
  return

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
  self = this

  add = (contact) ->
    if self._addrIsSelf(contact.addr)
      return
    if contact.token
      tokenful.add contact
    table.add contact
    return

  query = (addr) ->
    pending += 1
    queried[addr] = true
    if opts.findNode
      self._sendFindNode addr, id, onResponse.bind(null, addr)
    else
      self._sendGetPeers addr, id, onResponse.bind(null, addr)
    return

  queryClosest = ->
    self.nodes.closest({ id: id }, K).forEach (contact) ->
      query contact.addr
      return
    return

  # Note: `_sendFindNode` and `_sendGetPeers` will insert newly discovered nodes into
  # the routing table, so that's not done here.

  onResponse = (addr, err, res) ->
    if self._destroyed
      return cb(new Error('dht is destroyed'))
    pending -= 1
    nodeId = res and res.id
    nodeIdHex = idToHexString(nodeId)
    # ignore errors - they are just timeouts
    if err
      self._debug 'got lookup error: %s', err.message
    else
      self._debug 'got lookup response from %s', nodeIdHex
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
          return
    # find closest unqueried nodes
    candidates = table.closest({ id: id }, K).filter((contact) ->
      !queried[contact.addr]
    )
    while pending < MAX_CONCURRENCY and candidates.length
      # query as many candidates as our concurrency limit will allow
      query candidates.pop().addr
    if pending == 0 and candidates.length == 0
      # recursive lookup should terminate because there are no closer nodes to find
      self._debug 'terminating lookup %s %s', (if opts.findNode then '(find_node)' else '(get_peers)'), idHex
      closest = (if opts.findNode then table else tokenful).closest({ id: id }, K)
      self._debug 'K closest nodes are:'
      closest.forEach (contact) ->
        self._debug '  ' + contact.addr + ' ' + idToHexString(contact.id)
        return
      cb null, closest
    return

  id = idToBuffer(id)
  if typeof opts == 'function'
    cb = opts
    opts = {}
  if !opts
    opts = {}
  if !cb

    cb = ->

  cb = once(cb)
  if self._destroyed
    return cb(new Error('dht is destroyed'))
  if !self.listening
    return self.listen(self.lookup.bind(self, id, opts, cb))
  idHex = idToHexString(id)
  self._debug 'lookup %s %s', (if opts.findNode then '(find_node)' else '(get_peers)'), idHex
  # Return local peers, if we have any in our table
  peers = self.peers[idHex] and self.peers[idHex]
  if peers
    peers = parsePeerInfo(peers.list)
    peers.forEach (peerAddr) ->
      self._debug 'emit peer %s %s from %s', peerAddr, idHex, 'local'
      self.emit 'peer', peerAddr, idHex, 'local'
      return
  table = new KBucket(
    localNodeId: id
    numberOfNodesPerKBucket: K
    numberOfNodesToPing: MAX_CONCURRENCY)
  # NOT the same table as the one used for the lookup, as that table may have nodes without tokens
  if !self.tables[idHex]
    self.tables[idHex] = new KBucket(
      localNodeId: id
      numberOfNodesPerKBucket: K
      numberOfNodesToPing: MAX_CONCURRENCY)
  tokenful = self.tables[idHex]
  queried = {}
  pending = 0
  # pending queries
  if opts.addrs
    # kick off lookup with explicitly passed nodes (usually, bootstrap servers)
    opts.addrs.forEach query
  else
    # kick off lookup with nodes in the main table
    queryClosest()
  return

###*
# Called when another node sends a UDP message
# @param {Buffer} data
# @param {Object} rinfo
###

DHT::_onData = (data, rinfo) ->
  self = this
  addr = rinfo.address + ':' + rinfo.port
  message = undefined
  errMessage = undefined
  try
    message = bencode.decode(data)
    if !message
      throw new Error('message is empty')
  catch err
    errMessage = err.message + ' from ' + addr + ' (' + data + ')'
    self._debug errMessage
    self.emit 'warning', new Error(errMessage)
    return
  type = message.y and message.y.toString()
  if type != MESSAGE_TYPE.QUERY and type != MESSAGE_TYPE.RESPONSE and type != MESSAGE_TYPE.ERROR
    errMessage = 'unknown message type ' + type + ' from ' + addr
    self._debug errMessage
    self.emit 'warning', new Error(errMessage)
    return
  # self._debug('got data %s from %s', JSON.stringify(message), addr)
  # Attempt to add every (valid) node that we see to the routing table.
  # TODO: If they node is already in the table, just update the "last heard from" time
  nodeId = message.r and message.r.id or message.a and message.a.id
  if nodeId
    # TODO: verify that this a valid length for a nodeId
    # self._debug('adding (potentially) new node %s %s', idToHexString(nodeId), addr)
    self.addNode addr, nodeId, addr
  if type == MESSAGE_TYPE.QUERY
    self._onQuery addr, message
  else if type == MESSAGE_TYPE.RESPONSE or type == MESSAGE_TYPE.ERROR
    self._onResponseOrError addr, type, message
  return

###*
# Called when another node sends a query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onQuery = (addr, message) ->
  self = this
  query = message.q.toString()
  if typeof self.queryHandler[query] == 'function'
    self.queryHandler[query].call self, addr, message
  else
    errMessage = 'unexpected query type'
    self._debug errMessage
    self._sendError addr, message.t, ERROR_TYPE.METHOD_UNKNOWN, errMessage
  return

###*
# Called when another node sends a response or error.
# @param  {string} addr
# @param  {string} type
# @param  {Object} message
###

DHT::_onResponseOrError = (addr, type, message) ->
  self = this
  transactionId = Buffer.isBuffer(message.t) and message.t.length == 2 and message.t.readUInt16BE(0)
  transaction = self.transactions and self.transactions[addr] and self.transactions[addr][transactionId]
  err = null
  if type == MESSAGE_TYPE.ERROR
    err = new Error(if Array.isArray(message.e) then message.e.join(' ') else undefined)
  if !transaction or !transaction.cb
    # unexpected message!
    if err
      errMessage = 'got unexpected error from ' + addr + ' ' + err.message
      self._debug errMessage
      self.emit 'warning', new Error(errMessage)
    else
      self._debug 'got unexpected message from ' + addr + ' ' + JSON.stringify(message)
      self.emit 'warning', new Error(errMessage)
    return
  transaction.cb err, message.r
  return

###*
# Send a UDP message to the given addr.
# @param  {string} addr
# @param  {Object} message
# @param  {function=} cb  called once message has been sent
###

DHT::_send = (addr, message, cb) ->
  self = this
  if !self.listening
    return self.listen(self._send.bind(self, addr, message, cb))
  if !cb

    cb = ->

  addrData = addrToIPPort(addr)
  host = addrData[0]
  port = addrData[1]
  if !(port > 0 and port < 65535)
    return
  # self._debug('send %s to %s', JSON.stringify(message), addr)
  message = bencode.encode(message)
  self.socket.send message, 0, message.length, port, host, cb
  return

DHT::_query = (data, addr, cb) ->
  self = this
  if !data.a
    data.a = {}
  if !data.a.id
    data.a.id = self.nodeId
  transactionId = self._getTransactionId(addr, cb)
  message =
    t: transactionIdToBuffer(transactionId)
    y: MESSAGE_TYPE.QUERY
    q: data.q
    a: data.a
  if data.q == 'find_node'
    self._debug 'sent find_node %s to %s', data.a.target.toString('hex'), addr
  else if data.q == 'get_peers'
    self._debug 'sent get_peers %s to %s', data.a.info_hash.toString('hex'), addr
  self._send addr, message
  return

###*
# Send "ping" query to given addr.
# @param {string} addr
# @param {function} cb called with response
###

DHT::_sendPing = (addr, cb) ->
  self = this
  self._query { q: 'ping' }, addr, cb
  return

###*
# Called when another node sends a "ping" query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onPing = (addr, message) ->
  self = this
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r: id: self.nodeId
  self._debug 'got ping from %s', addr
  self._send addr, res
  return

###*
# Send "find_node" query to given addr.
# @param {string} addr
# @param {Buffer} nodeId
# @param {function} cb called with response
###

DHT::_sendFindNode = (addr, nodeId, cb) ->
  self = this
  data =
    q: 'find_node'
    a:
      id: self.nodeId
      target: nodeId

  onResponse = (err, res) ->
    if err
      return cb(err)
    if res.nodes
      res.nodes = parseNodeInfo(res.nodes)
      res.nodes.forEach (node) ->
        self.addNode node.addr, node.id, addr
        return
    cb null, res
    return

  self._query data, addr, onResponse
  return

###*
# Called when another node sends a "find_node" query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onFindNode = (addr, message) ->
  self = this
  nodeId = message.a and message.a.target
  if !nodeId
    errMessage = '`find_node` missing required `a.target` field'
    self._debug errMessage
    self._sendError addr, message.t, ERROR_TYPE.PROTOCOL, errMessage
    return
  self._debug 'got find_node %s from %s', idToHexString(nodeId), addr
  # Convert nodes to "compact node info" representation
  nodes = convertToNodeInfo(self.nodes.closest({ id: nodeId }, K))
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r:
      id: self.nodeId
      nodes: nodes
  self._send addr, res
  return

###*
# Send "get_peers" query to given addr.
# @param {string} addr
# @param {Buffer|string} infoHash
# @param {function} cb called with response
###

DHT::_sendGetPeers = (addr, infoHash, cb) ->
  self = this

  onResponse = (err, res) ->
    if err
      return cb(err)
    if res.nodes
      res.nodes = parseNodeInfo(res.nodes)
      res.nodes.forEach (node) ->
        self.addNode node.addr, node.id, addr
        return
    if res.values
      res.values = parsePeerInfo(res.values)
      res.values.forEach (peerAddr) ->
        self._debug 'emit peer %s %s from %s', peerAddr, infoHashHex, addr
        self.emit 'peer', peerAddr, infoHashHex, addr
        return
    cb null, res
    return

  infoHash = idToBuffer(infoHash)
  infoHashHex = idToHexString(infoHash)
  data =
    q: 'get_peers'
    a:
      id: self.nodeId
      info_hash: infoHash
  self._query data, addr, onResponse
  return

###*
# Called when another node sends a "get_peers" query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onGetPeers = (addr, message) ->
  self = this
  addrData = addrToIPPort(addr)
  infoHash = message.a and message.a.info_hash
  if !infoHash
    errMessage = '`get_peers` missing required `a.info_hash` field'
    self._debug errMessage
    self._sendError addr, message.t, ERROR_TYPE.PROTOCOL, errMessage
    return
  infoHashHex = idToHexString(infoHash)
  self._debug 'got get_peers %s from %s', infoHashHex, addr
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r:
      id: self.nodeId
      token: self._generateToken(addrData[0])
  peers = self.peers[infoHashHex] and self.peers[infoHashHex].list
  if peers
    # We know of peers for the target info hash. Peers are stored as an array of
    # compact peer info, so return it as-is.
    res.r.values = peers
  else
    # No peers, so return the K closest nodes instead. Convert nodes to "compact node
    # info" representation
    res.r.nodes = convertToNodeInfo(self.nodes.closest({ id: infoHash }, K))
  self._send addr, res
  return

###*
# Send "announce_peer" query to given host and port.
# @param {string} addr
# @param {Buffer|string} infoHash
# @param {number} port
# @param {Buffer} token
# @param {function=} cb called with response
###

DHT::_sendAnnouncePeer = (addr, infoHash, port, token, cb) ->
  self = this
  infoHash = idToBuffer(infoHash)
  if !cb

    cb = ->

  data =
    q: 'announce_peer'
    a:
      id: self.nodeId
      info_hash: infoHash
      port: port
      token: token
      implied_port: 0
  self._query data, addr, cb
  return

###*
# Called when another node sends a "announce_peer" query.
# @param  {string} addr
# @param  {Object} message
###

DHT::_onAnnouncePeer = (addr, message) ->
  self = this
  errMessage = undefined
  addrData = addrToIPPort(addr)
  infoHash = idToHexString(message.a and message.a.info_hash)
  if !infoHash
    errMessage = '`announce_peer` missing required `a.info_hash` field'
    self._debug errMessage
    self._sendError addr, message.t, ERROR_TYPE.PROTOCOL, errMessage
    return
  token = message.a and message.a.token
  if !self._isValidToken(token, addrData[0])
    errMessage = 'cannot `announce_peer` with bad token'
    self._sendError addr, message.t, ERROR_TYPE.PROTOCOL, errMessage
    return
  port = if message.a.implied_port != 0 then addrData[1] else message.a.port
  # use port in `announce_peer` message
  self._debug 'got announce_peer %s %s from %s with token %s', idToHexString(infoHash), port, addr, idToHexString(token)
  self._addPeer addrData[0] + ':' + port, infoHash
  # send acknowledgement
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r: id: self.nodeId
  self._send addr, res
  return

###*
# Send an error to given host and port.
# @param  {string} addr
# @param  {Buffer|number} transactionId
# @param  {number} code
# @param  {string} errMessage
###

DHT::_sendError = (addr, transactionId, code, errMessage) ->
  self = this
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
  self._debug 'sent error %s to %s', JSON.stringify(message), addr
  self._send addr, message
  return

###*
# Get a transaction id, and (optionally) set a function to be called
# @param  {string}   addr
# @param  {function} fn
###

DHT::_getTransactionId = (addr, fn) ->
  self = this

  onTimeout = ->
    reqs[transactionId] = null
    fn new Error('query timed out')
    return

  onResponse = (err, res) ->
    clearTimeout reqs[transactionId].timeout
    reqs[transactionId] = null
    fn err, res
    return

  fn = once(fn)
  reqs = self.transactions[addr]
  if !reqs
    reqs = self.transactions[addr] = {}
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
  self = this
  if !secret
    secret = self.secrets[0]
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
  self = this
  validToken0 = self._generateToken(host, self.secrets[0])
  validToken1 = self._generateToken(host, self.secrets[1])
  bufferEqual(token, validToken0) or bufferEqual(token, validToken1)

###*
# Rotate secrets. Secrets are rotated every 5 minutes and tokens up to ten minutes
# old are accepted.
###

DHT::_rotateSecrets = ->
  self = this
  # Initialize secrets array
  # self.secrets[0] is the current secret, used to generate new tokens
  # self.secrets[1] is the last secret, which is still accepted

  createSecret = ->
    new Buffer(hat(SECRET_ENTROPY), 'hex')

  if !self.secrets
    self.secrets = [
      createSecret()
      createSecret()
    ]
    return
  self.secrets[1] = self.secrets[0]
  self.secrets[0] = createSecret()
  return

###*
# Get a string that can be used to initialize and bootstrap the DHT in the
# future.
# @return {Array.<Object>}
###

DHT::toArray = ->
  self = this
  nodes = self.nodes.toArray().map((contact) ->
    # to remove properties added by k-bucket, like `distance`, etc.
    {
      id: contact.id.toString('hex')
      addr: contact.addr
    }
  )
  nodes

DHT::_addrIsSelf = (addr) ->
  self = this
  self._port and LOCAL_HOSTS[self.ipv].some((host) ->
    host + ':' + self._port == addr
  )

DHT::_debug = ->
  self = this
  args = [].slice.call(arguments)
  args[0] = '[' + idToHexString(self.nodeId).substring(0, 7) + '] ' + args[0]
  debug.apply null, args
  return
