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
}