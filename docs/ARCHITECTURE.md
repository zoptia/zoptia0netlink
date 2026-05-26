# zoptia0netlink Architecture

This document describes the internal architecture, design decisions, and
extension patterns of the zoptia0netlink library.

---

## Table of Contents

- [Module Diagram](#module-diagram)
- [Layer Description](#layer-description)
- [Key Data Structures](#key-data-structures)
- [Design Decisions](#design-decisions)
- [Netlink Protocol Primer](#netlink-protocol-primer)
- [Request / Response Flow](#request--response-flow)
- [How to Add New Operations](#how-to-add-new-operations)

---

## Module Diagram

```
 User Code
    |
    v
+------------------------------------------------------+
|  netlink.zig  (public facade)                        |
|  Re-exports all types and operations                 |
+------+--------+--------+---------+-------------------+
       |        |        |         |
       v        v        v         v
  +--------+ +------+ +-------+ +-------+
  |link.zig| |addr. | |route. | |neigh. |
  |        | |zig   | |zig    | |zig    |
  +---+----+ +--+---+ +---+---+ +---+---+
      |         |          |         |      Domain modules:
      |         |          |         |      build requests,
      |         |          |         |      parse responses
      +----+----+----+-----+----+----+
           |         |          |
           v         v          v
    +--------------------------------------+
    |  nl.zig  (transport + serialization) |
    |                                      |
    |  NetlinkSocket   - socket lifecycle  |
    |  NetlinkRequest  - message builder   |
    |  RtAttr          - attribute tree    |
    |  AttrIterator    - attribute parser  |
    |  Constants       - NL/RTM/IFLA/...   |
    |  Address         - IPv4/IPv6 union   |
    +------------------+-------------------+
                       |
                       | AF_NETLINK socket
                       | (sendto / recvfrom)
                       v
              +------------------+
              |   Linux Kernel   |
              |  (rtnetlink)     |
              +------------------+
```

### File inventory

| File           | Lines | Role |
|----------------|-------|------|
| `netlink.zig`  | ~77   | Public facade; re-exports types and functions |
| `nl.zig`       | ~690  | Socket management, message serialization/deserialization, constants |
| `types.zig`    | ~490  | Domain types (`LinkAttrs`, `Addr`, `Route`, `Neigh`, `IPNet`, enums) |
| `link.zig`     | ~480  | Link CRUD and flag-manipulation operations |
| `addr.zig`     | ~215  | Address add/replace/delete/list |
| `route.zig`    | ~210  | Route add/replace/delete/list |
| `neigh.zig`    | ~185  | Neighbor add/set/append/delete/list |

---

## Layer Description

### Layer 1: Public Facade (`netlink.zig`)

The entry point for users. Imports every other module and re-exports:

- All operation functions (e.g., `linkAdd`, `addrList`, `routeDel`, `neighSet`)
- All primary types (`LinkAttrs`, `Addr`, `Route`, `Neigh`, `IPNet`)
- All enums (`LinkType`, `LinkOperState`, `Scope`, `RouteProtocol`)
- Utility functions (`parseIPNet`, `parseIP`, `newIPNet`, `computeBroadcast`)
- Transport types (`NetlinkSocket`, `Address`)

Users import only `netlink.zig` and have access to the full API.

### Layer 2: Domain Modules (`link.zig`, `addr.zig`, `route.zig`, `neigh.zig`)

Each domain module follows the same pattern:

1. Define an error set specific to the domain (`LinkAddError`, `AddrError`,
   `RouteError`, `NeighError`). All error sets share a common core
   (`NetlinkError`, `SendFailed`, `ShortRead`, `WrongSenderPid`,
   `InvalidMessage`, `OutOfMemory`, `SocketError`, `GetSockNameFailed`,
   `Unexpected`) plus standard library socket/bind errors.

2. Provide public CRUD functions. Each function:
   - Builds a `NetlinkRequest` with the appropriate RTM message type and flags.
   - Populates the fixed-size protocol header (`IfInfoMsg`, `IfAddrMsg`,
     `RtMsg`, or `NdMsg`).
   - Attaches `RtAttr` attributes carrying the variable-length data (names,
     addresses, numeric values).
   - Calls `req.executeAlloc(sock, ...)` which serializes, sends, and waits
     for the kernel response.

3. Provide internal parse functions (`parseLinkMsg`, `parseRouteMsg`, etc.)
   that decode response payloads back into domain types.

### Layer 3: Transport and Serialization (`nl.zig`)

This is the core of the library. It contains:

- **`NetlinkSocket`** -- Wraps `AF_NETLINK` / `SOCK_RAW` socket operations:
  `open`, `close`, `send`, `receive`, and sequence tracking.

- **`NetlinkRequest`** -- A message builder with a 4096-byte internal buffer.
  Supports `addData` (raw struct bytes) and `addRtAttr` (serialized attribute
  trees). The `execute`/`executeAlloc` method serializes the complete message,
  sends it, and collects all response payloads in a loop, handling `NLMSG_DONE`,
  `NLMSG_ERROR`, and multi-part responses.

- **`RtAttr`** -- A recursive attribute tree. Each node has a type, optional
  data payload, and optional children. Serializes to the kernel's `rtattr`
  wire format with proper alignment.

- **`AttrIterator`** / **`parseAttrs`** -- Iterates over a byte buffer of
  packed `rtattr` structures, yielding `(type, data)` pairs. Strips
  `NLA_F_NESTED` and `NLA_F_NET_BYTEORDER` flags automatically.

- **`Address`** -- A tagged union of `[4]u8` (v4) and `[16]u8` (v6) with
  conversion, comparison, and formatting methods.

- **Helper functions** -- `uint32Attr`, `uint16Attr`, `uint8Attr`,
  `readUint32`, `readInt32`, `readUint16`, `nlmsgAlign`, `rtaAlign`,
  `bytesAsValue`, `asBytes`.

- **Constants** -- All netlink, rtnetlink, IFLA, IFA, RTA, NDA, NUD, NTF,
  IFF, RTPROT, and route table constants used by the domain modules.

### Layer 4: Linux Kernel

The library communicates with the kernel's rtnetlink subsystem over an
`AF_NETLINK` socket. All messages use native-endian byte order and 4-byte
alignment.

---

## Key Data Structures

### Wire-format Headers (extern structs)

These are `extern struct` types that match the kernel's binary layout byte for
byte. They are used as the fixed-size protocol header at the start of each
netlink message payload.

| Struct       | Size (bytes) | Used by      | Kernel equivalent |
|--------------|-------------|--------------|-------------------|
| `NlMsgHdr`   | 16          | All messages | `struct nlmsghdr`  |
| `IfInfoMsg`  | 16          | Link ops     | `struct ifinfomsg` |
| `IfAddrMsg`  | 8           | Address ops  | `struct ifaddrmsg` |
| `RtMsg`      | 12          | Route ops    | `struct rtmsg`     |
| `NdMsg`      | 12          | Neighbor ops | `struct ndmsg`     |
| `RtAttrHdr`  | 4           | All attrs    | `struct rtattr`    |
| `IfaCacheInfo`| 16         | Address ops  | `struct ifa_cacheinfo` |

### Attribute Tree (`RtAttr`)

`RtAttr` is a recursive structure for building the TLV (type-length-value)
attribute tree that follows each protocol header:

```
RtAttr {
    type_: u16           -- attribute type (e.g., IFLA_IFNAME)
    data: ?[]const u8    -- leaf payload (null for containers)
    children: ArrayList  -- nested attributes
}
```

Serialization writes a 4-byte `RtAttrHdr` (length + type), followed by the
data payload or recursively serialized children, with 4-byte alignment padding.

---

## Design Decisions

### Fixed-size buffers for names and strings

Interface names (`[16]u8`), labels (`[16]u8`), aliases (`[256]u8`), and
encapsulation types (`[32]u8`) use fixed-size arrays rather than
heap-allocated slices. This avoids per-field allocations and simplifies the
`LinkAttrs` struct, which can be passed by value without lifetime concerns.
The sizes match the kernel's own limits (`IFNAMSIZ = 16`).

A separate `*_len` field tracks the actual string length. Accessor methods
(`getName`, `setName`, `getLabel`, `getAlias`) abstract the raw buffer.

### Allocator patterns

The library uses two distinct allocation strategies:

1. **Internal / temporary allocations** -- Domain modules use
   `std.heap.page_allocator` for short-lived `RtAttr` children and for the
   `executeAlloc` result buffer. These are freed before the function returns.

2. **Caller-provided allocator** -- List functions (`linkList`, `addrList`,
   `routeList`, `neighList`) accept an `allocator` parameter. The returned
   slice is owned by the caller and must be freed with the same allocator.

This split keeps the API simple for write operations (no allocator needed) while
giving callers control over memory for read operations that return variable-size
results.

### Alignment-safe deserialization

The kernel sends netlink data that may not be aligned to Zig struct boundaries.
Rather than casting raw pointers (which would trigger undefined behavior), the
library uses `@memcpy` into a stack-local variable:

```zig
var msg_buf: nl.RtMsg = undefined;
@memcpy(std.mem.asBytes(&msg_buf), data[0..@sizeOf(nl.RtMsg)]);
```

The `bytesAsValue` helper in `nl.zig` encapsulates this same pattern. This
ensures correctness on architectures that do not support unaligned loads.

### Error handling

Each domain module defines its own error set that is a union of netlink
transport errors and standard library socket/bind errors. This gives callers
precise `catch` / `switch` capability. The generic `NetlinkError` variant
covers all kernel-side rejections (invalid parameters, permission denied,
object exists, etc.) -- the library does not currently decode individual
`errno` values from `NLMSG_ERROR` responses.

### Native endianness

All integer serialization uses `native_endian` (imported from
`@import("builtin").cpu.arch.endian()`). Netlink uses native byte order, not
network byte order, which is a common source of confusion. The `Address` type
stores IP addresses as raw byte arrays, which are endian-neutral.

---

## Netlink Protocol Primer

### Message format

Every netlink message starts with a 16-byte `NlMsgHdr`:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          Length                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Type                |            Flags              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Sequence Number                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Port ID (PID)                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| Field  | Description |
|--------|-------------|
| `len`  | Total message length including this header |
| `type_`| Message type: one of the `RTM_*` constants, or `NLMSG_ERROR`/`NLMSG_DONE` |
| `flags`| Bitwise OR of `NLM_F_*` flags |
| `seq`  | Sequence number for matching requests to responses |
| `pid`  | Sender port ID (0 = kernel) |

### Protocol headers

After `NlMsgHdr`, each RTM message type has a fixed-size protocol header:

- `RTM_*LINK` messages use `IfInfoMsg` (family, type, index, flags, change)
- `RTM_*ADDR` messages use `IfAddrMsg` (family, prefixlen, flags, scope, index)
- `RTM_*ROUTE` messages use `RtMsg` (family, dst_len, src_len, tos, table, protocol, scope, type, flags)
- `RTM_*NEIGH` messages use `NdMsg` (family, pad, ifindex, state, flags, type)

### Attribute tree (RtAttr / TLV)

After the protocol header, the remaining bytes are a sequence of TLV
(type-length-value) attributes. Each attribute has a 4-byte header:

```
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Length              |           Type                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Value ...                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- `Length` includes the 4-byte header itself.
- `Type` is one of the `IFLA_*`, `IFA_*`, `RTA_*`, or `NDA_*` constants.
  The high bits `NLA_F_NESTED` (0x8000) and `NLA_F_NET_BYTEORDER` (0x4000)
  are flags, stripped by `AttrIterator`.
- Attributes are padded to 4-byte boundaries (`RTA_ALIGNTO = 4`).
- Nested attributes (e.g., `IFLA_LINKINFO` containing `IFLA_INFO_KIND`) have
  `NLA_F_NESTED` set and their value is itself a sequence of attributes.

---

## Request / Response Flow

A typical write operation (e.g., `linkAdd`) proceeds as follows:

```
1. Build NetlinkRequest
   - Set RTM type (RTM_NEWLINK) and flags (NLM_F_CREATE | NLM_F_EXCL | NLM_F_ACK)
   - Append protocol header (IfInfoMsg) via addData()
   - Append attributes (IFLA_IFNAME, IFLA_MTU, ...) via addRtAttr()

2. Execute
   a. Assign sequence number from socket
   b. Set PID from socket's bound address
   c. Serialize header + data into send buffer (8192 bytes max)
   d. sendto() the kernel (destination pid = 0)

3. Receive loop
   a. recvfrom() into 65536-byte buffer
   b. Verify sender PID == 0 (kernel)
   c. Walk messages by NlMsgHdr.len:
      - Skip if sequence number does not match
      - NLMSG_DONE  -> return collected results
      - NLMSG_ERROR -> read errno; 0 = success (ACK), else error
      - Otherwise   -> copy payload, append to results list
      - If NLM_F_MULTI not set -> return immediately
   d. Repeat (kernel may send multiple datagrams for dumps)
```

Read operations (e.g., `linkList`) follow the same flow but use `NLM_F_DUMP`
and collect multiple payload messages. Each payload is then passed to the
domain-specific parser.

---

## How to Add New Operations

To add support for a new netlink operation (e.g., managing rules, qdiscs, or
new link attributes), follow this pattern:

### 1. Add constants to `nl.zig`

Add the necessary RTM message types, attribute type constants, and any new
protocol header structs:

```zig
// Example: adding rule support
pub const RTM_NEWRULE: u16 = 32;  // already present
pub const RTM_DELRULE: u16 = 33;
pub const RTM_GETRULE: u16 = 34;

pub const FRA_DST: u16 = 1;
pub const FRA_SRC: u16 = 2;
// ... more FRA_* constants
```

If a new fixed-size protocol header is needed, define it as an `extern struct`.

### 2. Add domain types to `types.zig`

Define the Zig-side data structure:

```zig
pub const Rule = struct {
    family: u8 = 0,
    table: u32 = 0,
    priority: u32 = 0,
    src: ?IPNet = null,
    dst: ?IPNet = null,
    // ...
};
```

### 3. Create a domain module (e.g., `rule.zig`)

Follow the structure of the existing domain modules:

```zig
// 1. Define error set
pub const RuleError = error{ ... } || std.posix.SocketError || std.posix.BindError;

// 2. Write operation: build request, execute, ignore result
pub fn ruleAdd(sock: *nl.NetlinkSocket, rule: *const types.Rule) RuleError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_NEWRULE, nl.NLM_F_CREATE | nl.NLM_F_EXCL | nl.NLM_F_ACK);
    // ... populate header and attributes ...
    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    // free result
}

// 3. Read operation: build dump request, parse responses
pub fn ruleList(sock: *nl.NetlinkSocket, family: u8, allocator: std.mem.Allocator) ![]types.Rule {
    var req = nl.NetlinkRequest.init(nl.RTM_GETRULE, nl.NLM_F_DUMP);
    // ... populate header ...
    const msgs = try req.executeAlloc(sock, allocator);
    defer { /* free msgs */ }
    // parse each message, return slice
}

// 4. Internal parser
fn parseRuleMsg(data: []const u8) types.Rule {
    // memcpy header, iterate attributes
}
```

### 4. Register in `netlink.zig`

Import the new module and re-export its public functions and types:

```zig
pub const rule = @import("rule.zig");
pub const Rule = types.Rule;
pub const ruleAdd = rule.ruleAdd;
pub const ruleList = rule.ruleList;
```

### 5. Key patterns to follow

- Use `@memcpy` into stack locals for deserialization (never cast unaligned pointers).
- Use `std.heap.page_allocator` for internal temporaries in write operations.
- Accept a caller-provided `allocator` for list/read operations.
- Define a domain-specific error set that includes the common transport errors.
- Use `nl.RtAttr.init` + `req.addRtAttr` for building attributes; call
  `deinit()` via `defer` to free the child list.
- Follow the naming convention: `<domain><Verb>` (e.g., `ruleAdd`,
  `ruleList`, `ruleDel`).
