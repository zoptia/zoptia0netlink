# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Documentation in 9 languages

[0.1.0]: https://github.com/zoptia/zoptianetlink/releases/tag/v0.1.0
