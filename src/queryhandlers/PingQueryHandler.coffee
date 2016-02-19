BaseQueryHandler = require './BaseQueryHandler'

# TODO move this to a `constants.coffee`
K = 20

###
Implementation of the basic 'ping'
as described in http://www.bittorrent.org/beps/bep_0005.html#ping

  The most basic query is a ping.

  "q" = "ping" A ping query has a single argument,
  "id" the value is a 20-byte string
    containing the senders node ID in network byte order.

  The appropriate response to a ping has a single key "id"
  containing the node ID of the responding node.

arguments:  {"id" : "<querying nodes id>"}

response: {"id" : "<queried nodes id>"}

###
class PingQueryHandler extends BaseQueryHandler

  @VALUES = [
    'id'
  ]
  @NAME = 'ping'

  ###
  @param nodeId {String} ID of the DHT node this is responding from
  ###
  constructor: (@nodeId)->
    super

  ###
  The appropriate response to a ping has a single key "id"
  containing the node ID of the responding node.
  @oaram id {String} querying nodes id
  ###
  main: (id)->
    {id: @nodeId}


module.exports = PingQueryHandler
