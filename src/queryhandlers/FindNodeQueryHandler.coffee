BaseQueryHandler = require('./BaseQueryHandler')
utils = require('../utils')
constants = require('../constants')

###

http://www.bittorrent.org/beps/bep_0005.html#find-node

Find node is used to find the contact information for a node given its ID.
"q" == "find_node"
A find_node query has two arguments:
  - "id" containing the node ID of the querying node
  - "target" containing the ID of the node sought by the queryer.

When a node receives a find_node query,
  it should respond with a key "nodes"
  and value of a string containing the compact node info for the target node
  or the K (8) closest good nodes in its own routing table.

arguments:  {"id" : "<querying nodes id>", "target" : "<id of target node>"}

response: {"id" : "<queried nodes id>", "nodes" : "<compact node info>"}

###
class FindNodeQueryHandler extends BaseQueryHandler

  @VALUES = [
    'id'
    'target'
  ]
  @NAME = 'find_node'

  ###
  @param nodeId {Buffer, String} ID of the node handling the response
  @param nodes {KBucket} a DHT node's known nodes
  ###
  constructor: (@dhtNode)->
    super

  ###
  @oaram id {String} querying nodes id
  @param target {String} id of target node
  ###
  main: (id, target)->
    # Convert nodes to "compact node info" representation
    nodes = utils.convertToNodeInfo(
      @dhtNode.nodes.closest({id: target}, constants.K)
    )
    {
      id: @nodeId
      nodes: nodes
    }

  ###
  @param response {Object}
  ###
  onResponse: (response, fromAddress)->
    if response.nodes
      response.nodes = utils.parseNodeInfo(response.nodes)
      for node in response.nodes
        @dhtNode.addNode node.addr, node.id, fromAddress


module.exports = FindNodeQueryHandler
