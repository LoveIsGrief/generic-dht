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



module.exports = {
  'fromArray': fromArray
  'idToBuffer': idToBuffer
  'convertToNodeInfo': convertToNodeInfo
}