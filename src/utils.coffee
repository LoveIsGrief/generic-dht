compact2string = require('compact2string')
crypto = require('crypto')
string2compact = require('string2compact')


###
Convert "contacts" from the routing table
  into "compact node info" representation.
@param  {Array.<Object>} contacts
@return {Buffer}
###
convertToNodeInfo = (contacts) ->
  Buffer.concat contacts.map((contact) ->
    Buffer.concat [
      contact.id
      string2compact(contact.addr)
    ]
  )

###
Ensure info hash or node id is a Buffer.
@param  {string|Buffer} id
@return {Buffer}
###
idToBuffer = (id) ->
  if Buffer.isBuffer(id)
    id
  else
    new Buffer(id, 'hex')

###
Ensure info hash or node id is a hex string.
@param  {string|Buffer} id
@return {Buffer}
###
idToHexString = (id) ->
  if Buffer.isBuffer(id)
    id.toString 'hex'
  else
    id

###
Parse saved string
@param  {Array.<Object>} nodes
@return {Buffer}
###
fromArray = (nodes) ->
  nodes.forEach (node) ->
    if node.id
      node.id = idToBuffer(node.id)
  nodes

###
Parse "compact node info" representation into "contacts".
@param  {Buffer} nodeInfo
@return {Array.<string>}  array of
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

# Return sha1 hash **as a buffer**
sha1 = (buf) ->
  crypto.createHash('sha1').update(buf).digest()


###
Ensure a transacation id is a 16-bit buffer, so it can be sent on the wire as
# the transaction id ("t" field).
@param  {number|Buffer} transactionId
@return {Buffer}
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
  'idToHexString': idToHexString
  'parseNodeInfo': parseNodeInfo
  'sha1': sha1
  'transactionIdToBuffer': transactionIdToBuffer
}
