# ZoptiaNetlink

**A pure Zig netlink library for Linux network management -- by [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English] | [简体中文](docs/i18n/README.zh-CN.md) | [日本語](docs/i18n/README.ja.md) | [한국어](docs/i18n/README.ko.md) | [Español](docs/i18n/README.es.md) | [Português](docs/i18n/README.pt-BR.md) | [Deutsch](docs/i18n/README.de.md) | [Français](docs/i18n/README.fr.md) | [Русский](docs/i18n/README.ru.md)

---

`ZoptiaNetlink` is a Zig netlink library that provides direct, type-safe access to the Linux netlink socket interface for managing network interfaces, routes, addresses, and neighbors. It serves as a programmatic iproute2 alternative, letting you configure every aspect of Linux network management -- creating and deleting links, assigning IP addresses, manipulating routing tables, and updating ARP/NDP neighbor entries -- all from native Zig code with no C dependencies and no shell-outs. The library communicates with the kernel through the netlink socket protocol (NETLINK_ROUTE), giving you the same low-level control that tools like `ip link`, `ip addr`, `ip route`, and `ip neigh` provide, but with compile-time safety and structured error handling.

## Features

### Link Management (Network Interfaces)

- `linkAdd` -- Create network interfaces (bridge, veth, vlan, dummy, bond, wireguard, and more)
- `linkDel` -- Delete network interfaces
- `linkList` -- Enumerate all network interfaces with full attribute details
- `linkByName` / `linkByIndex` -- Look up a single interface by name or kernel index
- `linkSetUp` / `linkSetDown` -- Bring interfaces up or down
- `linkSetMTU` -- Change the MTU of an interface
- `linkSetName` -- Rename an interface
- `linkSetMaster` / `linkSetNoMaster` -- Attach or detach an interface from a master (bridge, bond)
- `linkSetARPOn` / `linkSetARPOff` -- Enable or disable ARP on an interface
- `linkSetPromiscOn` / `linkSetPromiscOff` -- Enable or disable promiscuous mode
- `linkSetHardwareAddr` -- Set the MAC address of an interface

### Address Management (IP Addresses)

- `addrAdd` -- Assign an IP address to an interface
- `addrReplace` -- Add or replace an IP address on an interface
- `addrDel` -- Remove an IP address from an interface
- `addrList` -- List all IP addresses on an interface, filtered by address family

### Route Management (Routing Table)

- `routeAdd` -- Add a route to the routing table
- `routeReplace` -- Add or replace a route
- `routeDel` -- Delete a route from the routing table
- `routeList` -- List all routes for a given address family
- `routeListFiltered` -- List routes filtered by interface index

### Neighbor Management (ARP / NDP)

- `neighAdd` -- Add a neighbor (ARP/NDP) entry
- `neighSet` -- Add or replace a neighbor entry
- `neighAppend` -- Append a neighbor entry
- `neighDel` -- Delete a neighbor entry
- `neighList` -- List all neighbor entries, filtered by interface and address family

## Quick Start

### Add the dependency

Add `zoptianetlink` to your `build.zig.zon`:

```zig
.dependencies = .{
    .zoptianetlink = .{
        .url = "https://github.com/zoptia/zoptianetlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

Then in your `build.zig`:

```zig
const netlink_dep = b.dependency("zoptianetlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### Minimal example

```zig
const std = @import("std");
const netlink = @import("netlink");

pub fn main() !void {
    // Open a netlink socket
    var sock = try netlink.NetlinkSocket.open(netlink.nl.NETLINK_ROUTE);
    defer sock.close();

    // List all network interfaces
    const links = try netlink.linkList(&sock, std.heap.page_allocator);
    defer std.heap.page_allocator.free(links);

    for (links) |link| {
        std.debug.print("interface: {s} (index={d}, mtu={d}, state={s})\n", .{
            link.getName(),
            link.index,
            link.mtu,
            link.oper_state.toString(),
        });
    }
}
```

## Usage Examples

### Link: Create a bridge and bring it up

```zig
// Equivalent to:
//   ip link add br0 type bridge
//   ip link set br0 up

const netlink = @import("netlink");

var sock = try netlink.NetlinkSocket.open(netlink.nl.NETLINK_ROUTE);
defer sock.close();

var attrs = netlink.LinkAttrs{};
attrs.setName("br0");
attrs.link_type = .bridge;

try netlink.linkAdd(&sock, &attrs);

const br = try netlink.linkByName(&sock, "br0");
try netlink.linkSetUp(&sock, br.index);
```

### Address: Assign an IP address to an interface

```zig
// Equivalent to:
//   ip addr add 192.168.1.10/24 dev eth0

const netlink = @import("netlink");

var sock = try netlink.NetlinkSocket.open(netlink.nl.NETLINK_ROUTE);
defer sock.close();

const eth0 = try netlink.linkByName(&sock, "eth0");
const ipnet = try netlink.parseIPNet("192.168.1.10/24");

var addr = netlink.Addr{
    .ip = ipnet.ip,
    .prefix_len = ipnet.prefix_len,
};

try netlink.addrAdd(&sock, eth0.index, &addr);
```

### Route: Add a default gateway

```zig
// Equivalent to:
//   ip route add default via 192.168.1.1 dev eth0

const netlink = @import("netlink");

var sock = try netlink.NetlinkSocket.open(netlink.nl.NETLINK_ROUTE);
defer sock.close();

const eth0 = try netlink.linkByName(&sock, "eth0");
const gw = try netlink.parseIP("192.168.1.1");

const route = netlink.Route{
    .link_index = eth0.index,
    .gw = gw,
    .scope = .universe,
};

try netlink.routeAdd(&sock, &route);
```

### Neighbor: Add a static ARP entry

```zig
// Equivalent to:
//   ip neigh add 192.168.1.50 lladdr aa:bb:cc:dd:ee:ff dev eth0

const netlink = @import("netlink");

var sock = try netlink.NetlinkSocket.open(netlink.nl.NETLINK_ROUTE);
defer sock.close();

const eth0 = try netlink.linkByName(&sock, "eth0");
const ip = try netlink.parseIP("192.168.1.50");

const neigh = netlink.Neigh{
    .link_index = eth0.index,
    .ip = ip,
    .hardware_addr = .{ 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff },
    .state = netlink.nl.NUD_PERMANENT,
    .family = netlink.nl.FAMILY_V4,
};

try netlink.neighAdd(&sock, &neigh);
```

## Supported Link Types

| Link Type   | Enum Value  | Kernel String | Description                        |
|-------------|-------------|---------------|------------------------------------|
| Device      | `.device`   | `device`      | Physical network device            |
| Dummy       | `.dummy`    | `dummy`       | Dummy interface                    |
| IFB         | `.ifb`      | `ifb`         | Intermediate Functional Block      |
| Bridge      | `.bridge`   | `bridge`      | Ethernet bridge                    |
| VLAN        | `.vlan`     | `vlan`        | 802.1Q VLAN                        |
| Veth        | `.veth`     | `veth`        | Virtual Ethernet pair              |
| MACVLAN     | `.macvlan`  | `macvlan`     | MAC-based virtual LAN              |
| MACVTAP     | `.macvtap`  | `macvtap`     | MAC-based TAP                      |
| TUN/TAP     | `.tuntap`   | `tuntap`      | TUN/TAP device                     |
| VXLAN       | `.vxlan`    | `vxlan`       | Virtual Extensible LAN             |
| IPVLAN      | `.ipvlan`   | `ipvlan`      | IP-based virtual LAN               |
| Bond        | `.bond`     | `bond`        | Bonding (link aggregation)         |
| Geneve      | `.geneve`   | `geneve`      | Generic Network Virtualization     |
| GRE TAP     | `.gretap`   | `gretap`      | GRE L2 tunnel                      |
| GRE Tunnel  | `.gretun`   | `gre`         | GRE L3 tunnel                      |
| IP-in-IP    | `.iptun`    | `ipip`        | IPv4-in-IPv4 tunnel                |
| IP6TNL      | `.ip6tnl`   | `ip6tnl`      | IPv6 tunnel                        |
| SIT         | `.sit`      | `sit`         | IPv6-in-IPv4 tunnel                |
| VTI         | `.vti`      | `vti`         | Virtual Tunnel Interface           |
| VRF         | `.vrf`      | `vrf`         | Virtual Routing and Forwarding     |
| WireGuard   | `.wireguard`| `wireguard`   | WireGuard secure tunnel            |

## API Overview

| Module   | Function              | Description                                    |
|----------|-----------------------|------------------------------------------------|
| `link`   | `linkAdd`             | Create a new network interface                 |
| `link`   | `linkDel`             | Delete a network interface by index            |
| `link`   | `linkList`            | List all network interfaces                    |
| `link`   | `linkByName`          | Find an interface by name                      |
| `link`   | `linkByIndex`         | Find an interface by kernel index              |
| `link`   | `linkSetUp`           | Bring an interface up                          |
| `link`   | `linkSetDown`         | Bring an interface down                        |
| `link`   | `linkSetMTU`          | Set interface MTU                              |
| `link`   | `linkSetName`         | Rename an interface                            |
| `link`   | `linkSetMaster`       | Set interface master (bridge/bond)             |
| `link`   | `linkSetNoMaster`     | Remove interface from master                   |
| `link`   | `linkSetARPOn`        | Enable ARP                                     |
| `link`   | `linkSetARPOff`       | Disable ARP                                    |
| `link`   | `linkSetPromiscOn`    | Enable promiscuous mode                        |
| `link`   | `linkSetPromiscOff`   | Disable promiscuous mode                       |
| `link`   | `linkSetHardwareAddr` | Set MAC address                                |
| `addr`   | `addrAdd`             | Add an IP address to an interface              |
| `addr`   | `addrReplace`         | Add or replace an IP address                   |
| `addr`   | `addrDel`             | Remove an IP address from an interface         |
| `addr`   | `addrList`            | List IP addresses on an interface              |
| `route`  | `routeAdd`            | Add a route                                    |
| `route`  | `routeReplace`        | Add or replace a route                         |
| `route`  | `routeDel`            | Delete a route                                 |
| `route`  | `routeList`           | List routes by address family                  |
| `route`  | `routeListFiltered`   | List routes filtered by interface              |
| `neigh`  | `neighAdd`            | Add a neighbor entry                           |
| `neigh`  | `neighSet`            | Add or replace a neighbor entry                |
| `neigh`  | `neighAppend`         | Append a neighbor entry                        |
| `neigh`  | `neighDel`            | Delete a neighbor entry                        |
| `neigh`  | `neighList`           | List neighbor entries                          |
| `types`  | `parseIPNet`          | Parse a CIDR string (e.g. `"10.0.0.0/8"`)     |
| `types`  | `parseIP`             | Parse an IP address string                     |
| `types`  | `newIPNet`            | Create an IPNet with a host mask (/32 or /128) |
| `types`  | `computeBroadcast`    | Compute the broadcast address for a subnet     |

## Requirements

- **Linux** -- This library uses the Linux netlink interface and is not portable to other operating systems.
- **Root privileges** -- Most netlink operations that modify network configuration require `CAP_NET_ADMIN` or root access. Read-only operations (listing interfaces, addresses, routes, neighbors) may work without elevated privileges.
- **Zig 0.15+** -- Built and tested with Zig 0.15. The minimum version specified in `build.zig.zon` is 0.14.0, but 0.15+ is recommended.

## Testing

Run the full test suite using the provided script:

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

Integration tests modify network state and require root privileges. The script will automatically re-run with `sudo` if needed.

You can also run tests directly with Zig:

```bash
zig build test
```

## Contributing

Contributions are welcome. Please open an issue or submit a pull request on GitHub.

When submitting changes:

1. Ensure all tests pass (`./test.sh`)
2. Follow existing code style and naming conventions
3. Add tests for new functionality
4. Keep commits focused and well-described

## Security

If you discover a security vulnerability, please report it responsibly by emailing the maintainers rather than opening a public issue.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).

Copyright Zoptia. All rights reserved.
