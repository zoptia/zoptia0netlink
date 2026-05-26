# zoptia0netlink API Reference

zoptia0netlink is a Zig library for Linux netlink communication. It provides a
typed interface for managing network interfaces, IP addresses, routes, and
neighbor (ARP/NDP) entries. All operations require elevated privileges (root).

---

## Table of Contents

- [NetlinkSocket](#netlinksocket)
- [Link Operations](#link-operations)
- [Address Operations](#address-operations)
- [Route Operations](#route-operations)
- [Neighbor Operations](#neighbor-operations)
- [Types](#types)
- [Enums](#enums)
- [Utility Functions](#utility-functions)
- [Constants](#constants)

---

## NetlinkSocket

Defined in `src/nl.zig`. Wraps a raw netlink socket file descriptor and tracks
the kernel-assigned port ID and sequence counter.

### Fields

| Field | Type              | Description                          |
|-------|-------------------|--------------------------------------|
| `fd`  | `posix.fd_t`      | File descriptor for the netlink socket |
| `sa`  | `linux.sockaddr.nl` | Bound socket address (contains `pid`) |
| `seq` | `u32`             | Monotonically increasing sequence number |

### `open`

```zig
pub fn open(protocol: u32) !NetlinkSocket
```

Opens a netlink socket, binds it, and reads back the kernel-assigned port ID.

- **protocol** -- Netlink protocol family. Use `NETLINK_ROUTE` (0) for all
  link/addr/route/neigh operations.
- **Returns** -- A ready-to-use `NetlinkSocket`.
- **Errors** -- `SocketError`, `BindError`, `GetSockNameFailed`.

### `close`

```zig
pub fn close(self: *NetlinkSocket) void
```

Closes the underlying file descriptor and sets `fd` to -1.

### `send`

```zig
pub fn send(self: *NetlinkSocket, data: []const u8) !void
```

Sends a raw netlink message to the kernel (destination pid = 0).

- **Errors** -- `SendFailed`.

### `receive`

```zig
pub fn receive(self: *NetlinkSocket, buf: []u8) !struct { len: usize, pid: u32 }
```

Receives a netlink message into `buf`.

- **Returns** -- Number of bytes received and the sender's port ID.
- **Errors** -- `ShortRead` if fewer than `@sizeOf(NlMsgHdr)` bytes arrived.

### `getNextSeq`

```zig
pub fn getNextSeq(self: *NetlinkSocket) u32
```

Increments and returns the next sequence number. Used internally by
`NetlinkRequest.execute` to match requests with responses.

---

## Link Operations

All link functions are defined in `src/link.zig` and re-exported from the
root `netlink` module.

### `linkAdd`

```zig
pub fn linkAdd(sock: *NetlinkSocket, attrs: *const LinkAttrs) LinkAddError!void
```

Creates a new network interface.

- **attrs** -- Populate `name` (via `setName`), `link_type`, and optionally
  `mtu`, `tx_qlen`, `num_tx_queues`, `num_rx_queues`, `hardware_addr`, `group`.
- **Equivalent** -- `ip link add <name> type <type>`
- **Errors** -- `LinkAddError` (includes `NetlinkError`, `SendFailed`,
  `ShortRead`, `WrongSenderPid`, `InvalidMessage`, `OutOfMemory`,
  `SocketError`, `GetSockNameFailed`, `Unexpected`, plus `SocketError` and
  `BindError` from `std.posix`).

### `linkDel`

```zig
pub fn linkDel(sock: *NetlinkSocket, index: i32) LinkAddError!void
```

Deletes a network interface by its index.

- **Equivalent** -- `ip link del <name>`
- **Errors** -- `LinkAddError`.

### `linkList`

```zig
pub fn linkList(sock: *NetlinkSocket, allocator: std.mem.Allocator) ![]LinkAttrs
```

Returns all network interfaces as a caller-owned slice of `LinkAttrs`. The
caller must free the returned slice with the same allocator.

- **Equivalent** -- `ip link show`

### `linkByName`

```zig
pub fn linkByName(sock: *NetlinkSocket, name: []const u8) LinkError!LinkAttrs
```

Finds a single interface by name. Internally calls `linkList` and does a
linear scan.

- **Equivalent** -- `ip link show <name>`
- **Errors** -- `LinkError` (`LinkAddError` plus `LinkNotFound`).

### `linkByIndex`

```zig
pub fn linkByIndex(sock: *NetlinkSocket, index: i32) LinkError!LinkAttrs
```

Finds a single interface by its ifindex. Internally calls `linkList`.

- **Errors** -- `LinkError`.

### `linkSetUp`

```zig
pub fn linkSetUp(sock: *NetlinkSocket, index: i32) LinkAddError!void
```

Brings an interface up (sets the `IFF_UP` flag).

- **Equivalent** -- `ip link set <name> up`

### `linkSetDown`

```zig
pub fn linkSetDown(sock: *NetlinkSocket, index: i32) LinkAddError!void
```

Brings an interface down (clears the `IFF_UP` flag).

- **Equivalent** -- `ip link set <name> down`

### `linkSetMTU`

```zig
pub fn linkSetMTU(sock: *NetlinkSocket, index: i32, mtu: u32) LinkAddError!void
```

Sets the MTU of an interface.

- **Equivalent** -- `ip link set <name> mtu <mtu>`

### `linkSetName`

```zig
pub fn linkSetName(sock: *NetlinkSocket, index: i32, name: []const u8) LinkAddError!void
```

Renames an interface. The interface must be down. Maximum 15 characters.

- **Equivalent** -- `ip link set <name> name <newname>`

### `linkSetMaster`

```zig
pub fn linkSetMaster(sock: *NetlinkSocket, index: i32, master_index: i32) LinkAddError!void
```

Assigns a master device (e.g., adds a port to a bridge).

- **Equivalent** -- `ip link set <name> master <master>`

### `linkSetNoMaster`

```zig
pub fn linkSetNoMaster(sock: *NetlinkSocket, index: i32) LinkAddError!void
```

Removes the master device assignment. Calls `linkSetMaster` with
`master_index = 0`.

- **Equivalent** -- `ip link set <name> nomaster`

### `linkSetARPOff`

```zig
pub fn linkSetARPOff(sock: *NetlinkSocket, index: i32) LinkAddError!void
```

Disables ARP on an interface (sets `IFF_NOARP`).

- **Equivalent** -- `ip link set <name> arp off`

### `linkSetARPOn`

```zig
pub fn linkSetARPOn(sock: *NetlinkSocket, index: i32) LinkAddError!void
```

Enables ARP on an interface (clears `IFF_NOARP`).

- **Equivalent** -- `ip link set <name> arp on`

### `linkSetPromiscOn`

```zig
pub fn linkSetPromiscOn(sock: *NetlinkSocket, index: i32) LinkAddError!void
```

Enables promiscuous mode (sets `IFF_PROMISC`).

- **Equivalent** -- `ip link set <name> promisc on`

### `linkSetPromiscOff`

```zig
pub fn linkSetPromiscOff(sock: *NetlinkSocket, index: i32) LinkAddError!void
```

Disables promiscuous mode (clears `IFF_PROMISC`).

- **Equivalent** -- `ip link set <name> promisc off`

### `linkSetHardwareAddr`

```zig
pub fn linkSetHardwareAddr(sock: *NetlinkSocket, index: i32, hw_addr: [6]u8) LinkAddError!void
```

Sets the hardware (MAC) address of an interface. The interface should be down.

- **Equivalent** -- `ip link set <name> address <mac>`

---

## Address Operations

All address functions are defined in `src/addr.zig` and re-exported from the
root module.

### `addrAdd`

```zig
pub fn addrAdd(sock: *NetlinkSocket, link_index: i32, addr: *const Addr) AddrError!void
```

Adds an IP address to an interface. Fails if the address already exists.

- **Equivalent** -- `ip addr add <addr>/<prefix> dev <name>`
- **Errors** -- `AddrError`.

### `addrReplace`

```zig
pub fn addrReplace(sock: *NetlinkSocket, link_index: i32, addr: *const Addr) AddrError!void
```

Adds or replaces an IP address on an interface.

- **Equivalent** -- `ip addr replace <addr>/<prefix> dev <name>`
- **Errors** -- `AddrError`.

### `addrDel`

```zig
pub fn addrDel(sock: *NetlinkSocket, link_index: i32, addr: *const Addr) AddrError!void
```

Removes an IP address from an interface.

- **Equivalent** -- `ip addr del <addr>/<prefix> dev <name>`
- **Errors** -- `AddrError`.

### `addrList`

```zig
pub fn addrList(
    sock: *NetlinkSocket,
    link_index: i32,
    family: u8,
    allocator: std.mem.Allocator,
) ![]Addr
```

Lists IP addresses. Pass `link_index = 0` to list addresses on all
interfaces. Use `FAMILY_ALL`, `FAMILY_V4`, or `FAMILY_V6` for the family
filter.

- **Equivalent** -- `ip addr show [dev <name>]`

---

## Route Operations

All route functions are defined in `src/route.zig` and re-exported from the
root module.

### `routeAdd`

```zig
pub fn routeAdd(sock: *NetlinkSocket, route: *const Route) RouteError!void
```

Adds a new route. Fails if the route already exists.

- **Equivalent** -- `ip route add <dst> via <gw> dev <name>`
- **Errors** -- `RouteError`.

### `routeReplace`

```zig
pub fn routeReplace(sock: *NetlinkSocket, route: *const Route) RouteError!void
```

Adds or replaces a route.

- **Equivalent** -- `ip route replace <dst> via <gw> dev <name>`
- **Errors** -- `RouteError`.

### `routeDel`

```zig
pub fn routeDel(sock: *NetlinkSocket, route: *const Route) RouteError!void
```

Deletes a route.

- **Equivalent** -- `ip route del <dst>`
- **Errors** -- `RouteError`.

### `routeList`

```zig
pub fn routeList(sock: *NetlinkSocket, family: u8, allocator: std.mem.Allocator) ![]Route
```

Lists all routes for the given address family.

- **Equivalent** -- `ip route show`

### `routeListFiltered`

```zig
pub fn routeListFiltered(
    sock: *NetlinkSocket,
    family: u8,
    link_index: i32,
    allocator: std.mem.Allocator,
) ![]Route
```

Lists routes filtered by output interface index. Pass `link_index = 0` for
all routes (same as `routeList`).

- **Equivalent** -- `ip route show dev <name>`

---

## Neighbor Operations

All neighbor functions are defined in `src/neigh.zig` and re-exported from the
root module.

### `neighAdd`

```zig
pub fn neighAdd(sock: *NetlinkSocket, neigh: *const Neigh) NeighError!void
```

Adds a new ARP/NDP neighbor entry. Fails if the entry already exists.

- **Equivalent** -- `ip neigh add <ip> lladdr <mac> dev <name>`
- **Errors** -- `NeighError`.

### `neighSet`

```zig
pub fn neighSet(sock: *NetlinkSocket, neigh: *const Neigh) NeighError!void
```

Adds or replaces a neighbor entry.

- **Equivalent** -- `ip neigh replace <ip> lladdr <mac> dev <name>`
- **Errors** -- `NeighError`.

### `neighAppend`

```zig
pub fn neighAppend(sock: *NetlinkSocket, neigh: *const Neigh) NeighError!void
```

Appends an entry to the forwarding database (FDB). Used for bridge FDB
programming.

- **Equivalent** -- `bridge fdb append <mac> dev <name>`
- **Errors** -- `NeighError`.

### `neighDel`

```zig
pub fn neighDel(sock: *NetlinkSocket, neigh: *const Neigh) NeighError!void
```

Deletes a neighbor entry.

- **Equivalent** -- `ip neigh del <ip> dev <name>`
- **Errors** -- `NeighError`.

### `neighList`

```zig
pub fn neighList(
    sock: *NetlinkSocket,
    link_index: i32,
    family: u8,
    allocator: std.mem.Allocator,
) ![]Neigh
```

Lists neighbor entries. Pass `link_index = 0` for all interfaces. Use
`FAMILY_ALL` / `FAMILY_V4` / `FAMILY_V6` for family filtering.

- **Equivalent** -- `ip neigh show [dev <name>]`

---

## Types

### `LinkAttrs`

Defined in `src/types.zig`. Represents the attributes of a network interface.

| Field            | Type                | Default        | Description |
|------------------|---------------------|----------------|-------------|
| `index`          | `i32`               | `0`            | Kernel-assigned interface index (ifindex) |
| `mtu`            | `u32`               | `0`            | Maximum transmission unit in bytes |
| `tx_qlen`        | `i32`               | `-1`           | Transmit queue length; -1 means not set |
| `name`           | `[16]u8`            | all zeros      | Interface name as a fixed buffer (use `getName`/`setName`) |
| `name_len`       | `u8`                | `0`            | Actual length of the name |
| `hardware_addr`  | `?[6]u8`            | `null`         | MAC address (6 bytes), null if not set |
| `flags`          | `u32`               | `0`            | Interface flags (IFF_UP, IFF_NOARP, etc.) |
| `raw_flags`      | `u32`               | `0`            | Unmasked flags as returned by kernel |
| `parent_index`   | `i32`               | `0`            | ifindex of the parent link (IFLA_LINK) |
| `master_index`   | `i32`               | `0`            | ifindex of the master device (e.g., bridge) |
| `oper_state`     | `LinkOperState`     | `.unknown`     | RFC 2863 operational state |
| `statistics`     | `?LinkStatistics`   | `null`         | 64-bit interface statistics (IFLA_STATS64) |
| `group`          | `u32`               | `0`            | Interface group |
| `num_tx_queues`  | `u32`               | `0`            | Number of transmit queues |
| `num_rx_queues`  | `u32`               | `0`            | Number of receive queues |
| `gso_max_segs`   | `u32`               | `0`            | GSO maximum segments |
| `gso_max_size`   | `u32`               | `0`            | GSO maximum size |
| `gro_max_size`   | `u32`               | `0`            | GRO maximum size |
| `net_ns_id`      | `i32`               | `-1`           | Network namespace ID |
| `promisc`        | `u32`               | `0`            | Promiscuity counter |
| `allmulti`        | `u32`               | `0`            | All-multicast counter |
| `alias`          | `[256]u8`           | all zeros      | Interface alias (IFLA_IFALIAS) |
| `alias_len`      | `u8`                | `0`            | Actual length of alias |
| `link_type`      | `LinkType`          | `.device`      | Type of link (bridge, veth, dummy, etc.) |
| `encap_type`     | `[32]u8`            | all zeros      | Encapsulation type string |
| `encap_type_len` | `u8`                | `0`            | Actual length of encap_type |

**Methods:**

- `getName(self: *const LinkAttrs) []const u8` -- Returns the interface name as a slice.
- `setName(self: *LinkAttrs, name: []const u8) void` -- Copies the name into the fixed buffer (max 15 chars, null-terminated).
- `getAlias(self: *const LinkAttrs) []const u8` -- Returns the alias as a slice.

### `LinkStatistics` (`LinkStatistics64`)

A 23-field `extern struct` that mirrors the kernel `rtnl_link_stats64`. All
fields are `u64` with default `0`. Key fields:

`rx_packets`, `tx_packets`, `rx_bytes`, `tx_bytes`, `rx_errors`, `tx_errors`,
`rx_dropped`, `tx_dropped`, `multicast`, `collisions`, plus detailed error
counters (`rx_length_errors`, `rx_crc_errors`, `tx_carrier_errors`, etc.).

### `Addr`

Represents an IP address assigned to an interface.

| Field          | Type            | Default    | Description |
|----------------|-----------------|------------|-------------|
| `ip`           | `Address`       | (required) | The IP address |
| `prefix_len`   | `u8`            | (required) | CIDR prefix length |
| `label`        | `[16]u8`        | all zeros  | Address label (IPv4 only, e.g., "eth0:1") |
| `label_len`    | `u8`            | `0`        | Actual label length |
| `flags`        | `u32`           | `0`        | Address flags (IFA_F_SECONDARY, etc.) |
| `scope`        | `u8`            | `0`        | Address scope (RT_SCOPE_*) |
| `peer`         | `?IPNet`        | `null`     | Peer address for point-to-point links |
| `broadcast`    | `?Address`      | `null`     | Broadcast address; auto-computed for IPv4 if not set |
| `preferred_lft`| `u32`           | `0`        | Preferred lifetime in seconds |
| `valid_lft`    | `u32`           | `0`        | Valid lifetime in seconds |
| `link_index`   | `i32`           | `0`        | Interface index this address belongs to |
| `protocol`     | `u8`            | `0`        | Address protocol (IFA_PROTO) |

**Methods:**

- `getLabel(self: *const Addr) []const u8`
- `setLabel(self: *Addr, lbl: []const u8) void`
- `eql(self: *const Addr, other: *const Addr) bool` -- Compares IP and prefix length.
- `family(self: *const Addr) u8` -- Returns `FAMILY_V4` or `FAMILY_V6`.
- `ipNet(self: *const Addr) IPNet` -- Extracts the `IPNet` (ip + prefix_len).

### `IPNet`

An IP address with a prefix length.

| Field       | Type      | Description |
|-------------|-----------|-------------|
| `ip`        | `Address` | The IP address |
| `prefix_len`| `u8`     | CIDR prefix length |

**Methods:**

- `eql(self: *const IPNet, other: *const IPNet) bool`
- `contains(self: *const IPNet, addr: Address) bool` -- Tests whether `addr` falls within the subnet.

### `Route`

Represents a kernel routing table entry.

| Field        | Type            | Default      | Description |
|--------------|-----------------|--------------|-------------|
| `link_index` | `i32`           | `0`          | Output interface index |
| `scope`      | `Scope`         | `.universe`  | Route scope |
| `dst`        | `?IPNet`        | `null`       | Destination network; null means default route |
| `src`        | `?Address`      | `null`       | Preferred source address |
| `gw`         | `?Address`      | `null`       | Gateway address |
| `protocol`   | `RouteProtocol` | `.boot`      | Who originated the route |
| `priority`   | `u32`           | `0`          | Route metric / priority |
| `family`     | `u8`            | `0`          | Address family; auto-detected from dst/gw/src if 0 |
| `table`      | `u32`           | `RT_TABLE_MAIN` | Routing table ID (254 = main) |
| `type_`      | `u8`            | `RTN_UNICAST`| Route type |
| `tos`        | `u8`            | `0`          | Type of service |
| `flags`      | `u32`           | `0`          | Route flags |
| `mtu`        | `u32`           | `0`          | Route MTU |

**Methods:**

- `eql(self: *const Route, other: *const Route) bool` -- Compares link_index, dst, gw, scope, protocol, and table.

### `Neigh`

Represents a neighbor (ARP/NDP) table entry.

| Field           | Type       | Default    | Description |
|-----------------|------------|------------|-------------|
| `link_index`    | `i32`      | `0`        | Interface index |
| `family`        | `u8`       | `0`        | Address family; auto-detected from IP if 0 |
| `state`         | `u16`      | `0`        | Neighbor state (NUD_* flags) |
| `type_`         | `u8`       | `0`        | Neighbor type |
| `flags`         | `u8`       | `0`        | Neighbor flags (NTF_*) |
| `flags_ext`     | `u32`      | `0`        | Extended neighbor flags |
| `ip`            | `Address`  | (required) | IP address of the neighbor |
| `hardware_addr` | `?[6]u8`   | `null`     | Link-layer (MAC) address |
| `vlan`          | `u16`      | `0`        | VLAN ID |
| `vni`           | `u32`      | `0`        | VNI (VXLAN network identifier) |
| `master_index`  | `i32`      | `0`        | Master device ifindex |

**Methods:**

- `eql(self: *const Neigh, other: *const Neigh) bool` -- Compares ip, link_index, and state.

### `Address`

A tagged union representing an IPv4 or IPv6 address.

```zig
pub const Address = union(enum) {
    v4: [4]u8,
    v6: [16]u8,
};
```

**Methods:**

- `toBytes(self: *const Address) []const u8` -- Returns a 4- or 16-byte slice.
- `fromSlice(data: []const u8) !Address` -- Constructs from a 4- or 16-byte slice; returns `InvalidAddressLength` otherwise.
- `eql(self: Address, other: Address) bool` -- Byte-wise equality; different families are never equal.
- `format(self: Address, writer: anytype) !void` -- Writes dotted-decimal (v4) or colon-hex (v6) representation.
- `isZero(self: *const Address) bool` -- True if all bytes are zero.

---

## Enums

### `LinkType`

Identifies the kind of network interface. 21 values:

| Value       | `toString()` output | Description |
|-------------|---------------------|-------------|
| `.device`   | `"device"`          | Physical device (default) |
| `.dummy`    | `"dummy"`           | Dummy interface |
| `.ifb`      | `"ifb"`             | Intermediate Functional Block |
| `.bridge`   | `"bridge"`          | Ethernet bridge |
| `.vlan`     | `"vlan"`            | 802.1Q VLAN |
| `.veth`     | `"veth"`            | Virtual ethernet pair |
| `.macvlan`  | `"macvlan"`         | MAC-based VLAN |
| `.macvtap`  | `"macvtap"`         | MAC-based TAP |
| `.tuntap`   | `"tuntap"`          | TUN/TAP device |
| `.vxlan`    | `"vxlan"`           | VXLAN tunnel |
| `.ipvlan`   | `"ipvlan"`          | IP-based VLAN |
| `.bond`     | `"bond"`            | Bonding (link aggregation) |
| `.geneve`   | `"geneve"`          | GENEVE tunnel |
| `.gretap`   | `"gretap"`          | GRE TAP tunnel |
| `.gretun`   | `"gre"`             | GRE tunnel |
| `.iptun`    | `"ipip"`            | IP-in-IP tunnel |
| `.ip6tnl`   | `"ip6tnl"`          | IPv6 tunnel |
| `.sit`      | `"sit"`             | IPv6-in-IPv4 (SIT) tunnel |
| `.vti`      | `"vti"`             | Virtual Tunnel Interface |
| `.vrf`      | `"vrf"`             | Virtual Routing and Forwarding |
| `.wireguard`| `"wireguard"`       | WireGuard tunnel |
| `.generic`  | `"generic"`         | Catch-all for unknown types |

**Methods:**

- `toString(self: LinkType) []const u8`
- `fromString(s: []const u8) LinkType` -- Returns `.generic` for unrecognized strings.

### `LinkOperState`

RFC 2863 operational state of an interface.

| Value             | Numeric | Description |
|-------------------|---------|-------------|
| `.unknown`        | 0       | State unknown |
| `.not_present`    | 1       | Interface not present |
| `.down`           | 2       | Interface is down |
| `.lower_layer_down`| 3      | Lower layer (e.g., carrier) is down |
| `.testing`        | 4       | In testing mode |
| `.dormant`        | 5       | Waiting for external event |
| `.up`             | 6       | Operational and ready |

**Methods:**

- `toString(self: LinkOperState) []const u8`

### `Scope`

Route scope values.

| Value      | Numeric | Description |
|------------|---------|-------------|
| `.universe`| 0       | Global scope (default) |
| `.site`    | 200     | Site-local (IPv6) |
| `.link`    | 253     | Link-local |
| `.host`    | 254     | Host-local (loopback) |
| `.nowhere` | 255     | Destination does not exist |

**Methods:**

- `toString(self: Scope) []const u8`

### `RouteProtocol`

Describes the origin of a route.

| Value       | Numeric | Description |
|-------------|---------|-------------|
| `.unspec`   | 0       | Unspecified |
| `.redirect` | 1       | ICMP redirect |
| `.kernel`   | 2       | Kernel-generated |
| `.boot`     | 3       | Added during boot (default) |
| `.static_`  | 4       | Administratively configured |
| `_`         |         | Supports arbitrary `u8` values via `@enumFromInt` |

---

## Utility Functions

Defined in `src/types.zig` and re-exported from the root module.

### `parseIPNet`

```zig
pub fn parseIPNet(cidr: []const u8) !IPNet
```

Parses a CIDR-notation string (e.g., `"192.168.1.0/24"` or `"fd00::1/64"`)
into an `IPNet`.

- **Errors** -- `InvalidCIDR`, `InvalidIP`.

### `parseIP`

```zig
pub fn parseIP(ip_str: []const u8) !Address
```

Parses a dotted-decimal IPv4 or colon-hex IPv6 string into an `Address`.
Detects IPv6 by the presence of a `:` character. Supports `::` abbreviation
for IPv6.

- **Errors** -- `InvalidIP`.

### `newIPNet`

```zig
pub fn newIPNet(ip: Address) IPNet
```

Creates a host-scoped `IPNet` from a single address: `/32` for IPv4, `/128`
for IPv6.

### `computeBroadcast`

```zig
pub fn computeBroadcast(ip: [4]u8, prefix_len: u8) [4]u8
```

Computes the broadcast address for an IPv4 network by setting all host bits
to 1. Used internally by `addrAdd` / `addrReplace` when no explicit broadcast
is provided and prefix length is less than 31.

---

## Constants

Defined in `src/nl.zig`.

### Address Families

| Constant     | Value | Description |
|--------------|-------|-------------|
| `FAMILY_ALL` | 0     | `AF_UNSPEC` -- match all families |
| `FAMILY_V4`  | 2     | `AF_INET` -- IPv4 |
| `FAMILY_V6`  | 10    | `AF_INET6` -- IPv6 |
| `FAMILY_MPLS`| 28    | `AF_MPLS` |

### Netlink Message Flags (`NLM_F_*`)

| Constant          | Value    | Description |
|-------------------|----------|-------------|
| `NLM_F_REQUEST`   | `0x0001` | Message is a request |
| `NLM_F_MULTI`     | `0x0002` | Multipart message |
| `NLM_F_ACK`       | `0x0004` | Request an acknowledgement |
| `NLM_F_DUMP`      | `0x0300` | `NLM_F_ROOT \| NLM_F_MATCH` -- dump request |
| `NLM_F_CREATE`    | `0x0400` | Create object if it does not exist |
| `NLM_F_EXCL`      | `0x0200` | Fail if object already exists |
| `NLM_F_REPLACE`   | `0x0100` | Replace existing object |
| `NLM_F_APPEND`    | `0x0800` | Append to existing set |

### Netlink Message Types (`NLMSG_*`)

| Constant        | Value | Description |
|-----------------|-------|-------------|
| `NLMSG_NOOP`    | 1     | No operation |
| `NLMSG_ERROR`   | 2     | Error or ACK response |
| `NLMSG_DONE`    | 3     | End of multipart dump |
| `NLMSG_OVERRUN` | 4     | Overrun notification |

### RTM Message Types

| Constant        | Value | Description |
|-----------------|-------|-------------|
| `RTM_NEWLINK`   | 16    | Create or modify a link |
| `RTM_DELLINK`   | 17    | Delete a link |
| `RTM_GETLINK`   | 18    | Get/dump links |
| `RTM_SETLINK`   | 19    | Set link attributes |
| `RTM_NEWADDR`   | 20    | Add an address |
| `RTM_DELADDR`   | 21    | Delete an address |
| `RTM_GETADDR`   | 22    | Get/dump addresses |
| `RTM_NEWROUTE`  | 24    | Add a route |
| `RTM_DELROUTE`  | 25    | Delete a route |
| `RTM_GETROUTE`  | 26    | Get/dump routes |
| `RTM_NEWNEIGH`  | 28    | Add a neighbor entry |
| `RTM_DELNEIGH`  | 29    | Delete a neighbor entry |
| `RTM_GETNEIGH`  | 30    | Get/dump neighbor entries |

### Interface Flags (`IFF_*`)

| Constant          | Value    | Description |
|-------------------|----------|-------------|
| `IFF_UP`          | `0x1`    | Interface is up |
| `IFF_BROADCAST`   | `0x2`    | Valid broadcast address set |
| `IFF_LOOPBACK`    | `0x8`    | Loopback interface |
| `IFF_POINTOPOINT` | `0x10`   | Point-to-point link |
| `IFF_NOARP`       | `0x80`   | No ARP protocol |
| `IFF_PROMISC`     | `0x100`  | Promiscuous mode |
| `IFF_ALLMULTI`     | `0x200`  | Receive all multicast |
| `IFF_MULTICAST`   | `0x1000` | Supports multicast |

### Neighbor States (`NUD_*`)

| Constant         | Value  | Description |
|------------------|--------|-------------|
| `NUD_NONE`       | `0x00` | No state |
| `NUD_INCOMPLETE` | `0x01` | Resolution in progress |
| `NUD_REACHABLE`  | `0x02` | Confirmed reachable |
| `NUD_STALE`      | `0x04` | Reachability unconfirmed |
| `NUD_DELAY`      | `0x08` | Waiting for confirmation |
| `NUD_PROBE`      | `0x10` | Actively probing |
| `NUD_FAILED`     | `0x20` | Resolution failed |
| `NUD_NOARP`      | `0x40` | No ARP needed (static) |
| `NUD_PERMANENT`  | `0x80` | Permanent static entry |

### Neighbor Flags (`NTF_*`)

| Constant    | Value  | Description |
|-------------|--------|-------------|
| `NTF_USE`   | `0x01` | Use this entry for output |
| `NTF_SELF`  | `0x02` | Local station (FDB) |
| `NTF_MASTER`| `0x04` | Bridged entry |
| `NTF_PROXY` | `0x08` | Proxy ARP/NDP entry |

### Route Tables

| Constant          | Value | Description |
|-------------------|-------|-------------|
| `RT_TABLE_UNSPEC` | 0     | Unspecified |
| `RT_TABLE_MAIN`   | 254   | Main routing table (default) |
| `RT_TABLE_LOCAL`  | 255   | Local routing table |

### Route Types (`RTN_*`)

| Constant          | Value | Description |
|-------------------|-------|-------------|
| `RTN_UNSPEC`      | 0     | Unspecified |
| `RTN_UNICAST`     | 1     | Gateway or direct route |
| `RTN_LOCAL`       | 2     | Local interface route |
| `RTN_BROADCAST`   | 3     | Broadcast route |
| `RTN_UNREACHABLE` | 7     | Destination unreachable |
