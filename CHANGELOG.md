# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-05-26

### Added

- Transparent retry on `NLM_F_DUMP_INTR` (up to 10 attempts; opt-out via `NetlinkSocket.retry_dump_interrupted`)
- Kernel-side `NETLINK_EXT_ACK` reporting; readable extack message via `sock.lastExtAck()`
- `NETLINK_GET_STRICT_CHK` enabled so kernel honors per-request filters
- `addrList` passes ifindex in `RTM_GETADDR` for kernel-side filtering
- VLAN-specific data on link create: `vlan_id`, `vlan_proto`, `vlan_flags`, `vlan_flags_mask` (`IFLA_VLAN_*`)
- gretap/gretun: `gre_ignore_df` (`IFLA_GRE_IGNORE_DF`)
- VXLAN: `vxlan_id`, `vxlan_vni_filter` (`IFLA_VXLAN_VNIFILTER`)
- Generic `IFLA_HEADROOM` / `IFLA_TAILROOM` parsing
- Route `expires` field (`RTA_EXPIRES`)
- IPv6 LWT tunnel encap on routes (`Ip6tnlEncap` with network-byte-order ID and FLAGS)

### Changed

- Minimum Zig version: 0.16.0 (was 0.14.0)
- Replaced `std.posix.socket`/`bind`/`close` with direct `linux.*` syscalls and `linux.errno` checks
- `std.ArrayList` initialized as `.empty` per Zig 0.16 API

## [0.1.0] - 2026-03-20

### Added

- Core netlink socket communication layer (`NetlinkSocket`, `NetlinkRequest`, `RtAttr`)
- Link operations: `linkAdd`, `linkDel`, `linkList`, `linkByName`, `linkByIndex`, `linkSetUp`, `linkSetDown`, `linkSetMTU`, `linkSetName`, `linkSetMaster`, `linkSetNoMaster`, `linkSetARPOff`, `linkSetARPOn`, `linkSetPromiscOn`, `linkSetPromiscOff`, `linkSetHardwareAddr`
- Address operations: `addrAdd`, `addrReplace`, `addrDel`, `addrList`
- Route operations: `routeAdd`, `routeReplace`, `routeDel`, `routeList`, `routeListFiltered`
- Neighbor operations: `neighAdd`, `neighSet`, `neighAppend`, `neighDel`, `neighList`
- Utility functions: `parseIPNet`, `parseIP`, `newIPNet`, `computeBroadcast`
- Support for 21 link types: device, dummy, ifb, bridge, vlan, veth, macvlan, macvtap, tuntap, vxlan, ipvlan, bond, geneve, gretap, gretun, iptun, ip6tnl, sit, vti, vrf, wireguard
- 97 test cases (unit and integration)
- Test runner script (`test.sh`)

[0.2.0]: https://github.com/zoptia/zoptia0netlink/releases/tag/v0.2.0
[0.1.0]: https://github.com/zoptia/zoptia0netlink/releases/tag/v0.1.0
