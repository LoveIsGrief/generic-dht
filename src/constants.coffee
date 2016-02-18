os = require('os')

module.exports.BOOTSTRAP_NODES = [
  'router.bittorrent.com:6881'
  'router.utorrent.com:6881'
  'dht.transmissionbt.com:6881'
]
module.exports.BOOTSTRAP_TIMEOUT = 10000
module.exports.K = 20

# number of nodes per bucket
module.exports.MAX_CONCURRENCY = 6

# α from Kademlia paper
module.exports.ROTATE_INTERVAL = 5 * 60 * 1000

# rotate secrets every 5 minutes
module.exports.SECRET_ENTROPY = 160

# entropy of token secrets
module.exports.SEND_TIMEOUT = 2000
module.exports.MESSAGE_TYPE =
  QUERY: 'q'
  RESPONSE: 'r'
  ERROR: 'e'
module.exports.ERROR_TYPE =
  GENERIC: 201
  SERVER: 202
  PROTOCOL: 203
  METHOD_UNKNOWN: 204
module.exports.LOCAL_HOSTS = LOCAL_HOSTS =
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
