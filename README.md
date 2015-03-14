# generic-dht

### Simple, robust, generic DHT implementation

Generic Node.js implementation of the [BitTorrent DHT protocol](http://www.bittorrent.org/beps/bep_0005.html). BitTorrent DHT is the main peer discovery layer for BitTorrent, which allows for trackerless torrents. DHTs are awesome!

This implementation takes out all bittorrent specificities from it's parent [bittorrent-dht](https://github.com/feross/bittorrent-dht)


### features

- complete implementation of the DHT protocol in JavaScript
- follows [the spec](http://www.bittorrent.org/beps/bep_0005.html) (removing bittorrent specific stuff)
- efficient recursive lookup algorithm minimizes UDP traffic
- supports multiple, concurrent lookups using the same routing table


### install

```
npm install generic-dht
```

### api

#### `dht = new DHT([opts])`

Create a new `dht` instance.

If `opts` is specified, then the default options (shown below) will be overridden.

``` js
{
  nodeId: '',   // 160-bit DHT node ID (Buffer or hex string, default: randomly generated)
  bootstrap: [] // bootstrap servers (default: router.bittorrent.com:6881, router.utorrent.com:6881, dht.transmissionbt.com:6881)
}
```


#### `dht.lookup(key, [callback])`

Find values for the given key.

This does a recursive lookup in the DHT. Potential values that are discovered are emitted
as `value` events. See the `value` event below for more info.

`key` can be a string or Buffer. `callback` is called when the recursive lookup has
terminated, and is called with two paramaters. The first is an `Error` or null. The second
is an array of the K closest nodes. You usually don't need to use this info and can simply
listen for `value` events.

Note: `dht.lookup()` should only be called after the ready event has fired, otherwise the
lookup may fail because the DHT routing table doesn't contain enough nodes.


#### `dht.listen([port], [address], [onlistening])`

Make the DHT listen on the given `port`. If `port` is undefined, an available port is
automatically picked.

If `address` is undefined, the DHT will try to listen on all addresses.

If `onlistening` is defined, it is attached to the `listening` event.


#### `dht.address()`

Returns an object containing the address information for the listening socket of the DHT.
This object contains `address`, `family` and `port` properties.


#### `arr = dht.toArray()`

Returns the nodes in the DHT as an array. This is useful for persisting the DHT
to disk between restarts of a BitTorrent client (as recommended by the spec). Each node in the array is an object with `id` (hex string) and `addr` (string) properties.

To restore the DHT nodes when instantiating a new `DHT` object, simply pass in the array as the value of the `bootstrap` option.

```js
var dht1 = new DHT()

// some time passes ...

// destroy the dht
var arr = dht1.toArray()
dht1.destroy()

// some time passes ...

// initialize a new dht with the same routing table as the first
var dht2 = new DHT({ bootstrap: arr })
```


#### `dht.addNode(addr, [nodeId])`

Manually add a node to the DHT routing table. If there is space in the routing table (or
an unresponsive node can be evicted to make space), the node will be added. If not, the
node will not be added. This is useful to call when a peer wire sends a `PORT` message to
share their DHT port.

If `nodeId` is undefined, then the peer will be pinged to learn their node id. If the peer does not respond, the will not be added to the routing table.


#### `dht.destroy([callback])`

Destroy the DHT. Closes the socket and cleans up large data structure resources.


### events

#### `dht.on('ready', function () { ... })`

Emitted when the DHT is ready to handle lookups (i.e. the routing table is sufficiently
populated via the bootstrap nodes).

Note: If you initialize the DHT with the `{ bootstrap: false }` option, then the 'ready'
event will fire on the next tick even if there are not any nodes in the routing table.
It is assumed that you will manually populate the routing table with `dht.addNode` if you
pass this option.


#### `dht.on('listening', function () { ... })`

Emitted when the DHT is listening.


#### `dht.on('value', function (value, key, from) { ... })`

Emitted when a potential value is found. `value` is of the form `IP_ADDRESS:PORT`.
`key` is what was used when calling `lookup(key)` call.


#### `dht.on('error', function (err) { ... })`

Emitted when the DHT has a fatal error.


#### internal events

#### `dht.on('node', function (addr, nodeId, from) { ... })`

Emitted when the DHT finds a new node.


#### `dht.on('warning', function (err) { ... })`

Emitted when the DHT gets an unexpected message from another DHT node. This is purely
informational.


### further reading

- [BitTorrent DHT protocol](http://www.bittorrent.org/beps/bep_0005.html)
- [Kademlia: A Peer-to-peer Information System Based on the XOR Metric](http://www.cs.rice.edu/Conferences/IPTPS02/109.pdf)


### license

MIT. Copyright
