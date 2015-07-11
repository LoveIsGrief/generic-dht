compact2string = require('compact2string')
string2compact = require('string2compact')


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

module.exports = {
  'convertToNodeInfo': convertToNodeInfo
  'fromArray': fromArray
  'idToBuffer': idToBuffer
  'parseNodeInfo': parseNodeInfo
  'parsePeerInfo': parsePeerInfo
  'transactionIdToBuffer': transactionIdToBuffer
}