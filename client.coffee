# allow override for chrome apps (chrome-dgram)
addrToIPPort = require('addr-to-ip-port')
bencode = require('bencode')
bufferEqual = require('buffer-equal')
debug = require('debug')('bittorrent-dht')
dgram = require('dgram')
dns = require('dns')
EventEmitter = require('events').EventEmitter
hat = require('hat')
isIP = require('is-ip')
KBucket = require('k-bucket')
once = require('once')
os = require('os')
parallel = require('run-parallel')
string2compact = require('string2compact')
utils = require './utils'

#
# Constants
#

BOOTSTRAP_NODES = [
  'router.bittorrent.com:6881'
  'router.utorrent.com:6881'
  'dht.transmissionbt.com:6881'
]
BOOTSTRAP_TIMEOUT = 10000
K = 20
# number of nodes per bucket
MAX_CONCURRENCY = 6
# α from Kademlia paper
ROTATE_INTERVAL = 5 * 60 * 1000
# rotate secrets every 5 minutes
SECRET_ENTROPY = 160
# entropy of token secrets
SEND_TIMEOUT = 2000
MESSAGE_TYPE =
  QUERY: 'q'
  RESPONSE: 'r'
  ERROR: 'e'
ERROR_TYPE =
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

###*
# A DHT client implementation. The DHT is the main peer discovery layer for BitTorrent,
# which allows for trackerless torrents.
# @param {string|Buffer} opts
###

class DHT extends EventEmitter

  # These constants will also be exported
  @ERROR_TYPE = ERROR_TYPE
  @K = K
  @MESSAGE_TYPE = MESSAGE_TYPE

  constructor: (opts) ->
    if !(@ instanceof DHT)
      return new DHT(opts)
    EventEmitter.call @
    if !debug.enabled
      @setMaxListeners 0
    if !opts
      opts = {}
    @nodeId = utils.idToBuffer(opts.nodeId or hat(160))
    @ipv = opts.ipv or 4
    @_debug 'new DHT %s', utils.idToHexString(@nodeId)
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

    # Create socket and attach listeners
    @socket = dgram.createSocket('udp' + @ipv)
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
        @_bootstrap utils.fromArray(opts.bootstrap)
      else
        # opts.bootstrap is undefined or true
        @_bootstrap BOOTSTRAP_NODES
    @on 'ready', ->
      @_debug 'emit ready'

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
  nodeId = utils.idToBuffer(nodeId)
  return if @_addrIsSelf(addr)
    # @_debug('skipping adding %s since that is us!', addr)
  contact =
    id: nodeId
    addr: addr
  @nodes.add contact
  # TODO: only emit this event for new nodes
  @emit 'node', addr, nodeId, from
  @_debug 'addNode %s %s discovered from %s', utils.idToHexString(nodeId), addr, from

###*
# Remove a DHT node from the routing table.
# @param  {string|Buffer} nodeId
###

DHT::removeNode = (nodeId) ->
  return if @_destroyed
  contact = @nodes.get(utils.idToBuffer(nodeId))
  if contact
    @_debug 'removeNode %s %s', contact.nodeId, contact.addr
    @nodes.remove contact

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
    @_sendFindNode addr, id, onResponse.bind(null, addr)

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
    nodeIdHex = utils.idToHexString(nodeId)
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
        @_debug '  ' + contact.addr + ' ' + utils.idToHexString(contact.id)
      cb null, closest

  id = utils.idToBuffer(id)
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
  idHex = utils.idToHexString(id)
  @_debug 'lookup %s %s', '(find_node)' , idHex
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
    # @_debug('adding (potentially) new node %s %s', utils.idToHexString(nodeId), addr)
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
    t: utils.transactionIdToBuffer(transactionId)
    y: MESSAGE_TYPE.QUERY
    q: data.q
    a: data.a
  if data.q == 'find_node'
    @_debug 'sent %s %s to %s', data.q, data.a.target.toString('hex'), addr
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
      res.nodes = utils.parseNodeInfo(res.nodes)
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
  @_debug 'got find_node %s from %s', utils.idToHexString(nodeId), addr
  # Convert nodes to "compact node info" representation
  nodes = utils.convertToNodeInfo(@nodes.closest({ id: nodeId }, K))
  res =
    t: message.t
    y: MESSAGE_TYPE.RESPONSE
    r:
      id: @nodeId
      nodes: nodes
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
    transactionId = utils.transactionIdToBuffer(transactionId)
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
  args[0] = '[' + utils.idToHexString(@nodeId).substring(0, 7) + '] ' + args[0]
  debug.apply null, args

module.exports = DHT
