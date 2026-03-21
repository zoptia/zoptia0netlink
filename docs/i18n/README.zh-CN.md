# zoptianetlink

**纯 Zig 实现的 Linux netlink 网络管理库 -- [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English](../../README.md) | [简体中文] | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Português](README.pt-BR.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | [Русский](README.ru.md)

---

`zoptianetlink` 是一个纯 Zig 实现的 netlink 库，提供对 Linux netlink 套接字接口的直接、类型安全的访问，用于管理网络接口、路由、地址和邻居表项。它可以作为 iproute2 的编程替代方案，让你通过纯 Zig 代码配置 Linux 网络管理的各个方面——创建和删除链路、分配 IP 地址、操作路由表以及更新 ARP/NDP 邻居表项——无需 C 依赖，无需调用外部命令。该库通过 netlink 套接字协议（NETLINK_ROUTE）与内核通信，提供与 `ip link`、`ip addr`、`ip route` 和 `ip neigh` 等工具相同的底层控制能力，同时具备编译时安全性和结构化错误处理。

## 功能特性

### 链路管理（网络接口）

- `linkAdd` -- 创建网络接口（bridge、veth、vlan、dummy、bond、wireguard 等）
- `linkDel` -- 删除网络接口
- `linkList` -- 列举所有网络接口及其完整属性详情
- `linkByName` / `linkByIndex` -- 按名称或内核索引查找单个接口
- `linkSetUp` / `linkSetDown` -- 启用或禁用接口
- `linkSetMTU` -- 更改接口的 MTU
- `linkSetName` -- 重命名接口
- `linkSetMaster` / `linkSetNoMaster` -- 将接口附加到主设备（bridge、bond）或从主设备分离
- `linkSetARPOn` / `linkSetARPOff` -- 启用或禁用接口上的 ARP
- `linkSetPromiscOn` / `linkSetPromiscOff` -- 启用或禁用混杂模式
- `linkSetHardwareAddr` -- 设置接口的 MAC 地址

### 地址管理（IP 地址）

- `addrAdd` -- 为接口分配 IP 地址
- `addrReplace` -- 添加或替换接口上的 IP 地址
- `addrDel` -- 从接口移除 IP 地址
- `addrList` -- 列出接口上的所有 IP 地址，支持按地址族过滤

### 路由管理（路由表）

- `routeAdd` -- 向路由表添加路由
- `routeReplace` -- 添加或替换路由
- `routeDel` -- 从路由表删除路由
- `routeList` -- 列出指定地址族的所有路由
- `routeListFiltered` -- 按接口索引过滤列出路由

### 邻居管理（ARP / NDP）

- `neighAdd` -- 添加邻居（ARP/NDP）表项
- `neighSet` -- 添加或替换邻居表项
- `neighAppend` -- 追加邻居表项
- `neighDel` -- 删除邻居表项
- `neighList` -- 列出所有邻居表项，支持按接口和地址族过滤

## 快速入门

### 添加依赖

将 `zoptianetlink` 添加到你的 `build.zig.zon`：

```zig
.dependencies = .{
    .zoptianetlink = .{
        .url = "https://github.com/zoptia/zoptianetlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

然后在你的 `build.zig` 中：

```zig
const netlink_dep = b.dependency("zoptianetlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### 最小示例

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

## 使用示例

### 链路：创建网桥并启用

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

### 地址：为接口分配 IP 地址

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

### 路由：添加默认网关

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

### 邻居：添加静态 ARP 表项

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

## 支持的链路类型

| 链路类型     | 枚举值         | 内核字符串      | 说明                              |
|-------------|---------------|----------------|-----------------------------------|
| Device      | `.device`     | `device`       | 物理网络设备                        |
| Dummy       | `.dummy`      | `dummy`        | 虚拟接口                           |
| IFB         | `.ifb`        | `ifb`          | 中间功能块                          |
| Bridge      | `.bridge`     | `bridge`       | 以太网网桥                          |
| VLAN        | `.vlan`       | `vlan`         | 802.1Q VLAN                       |
| Veth        | `.veth`       | `veth`         | 虚拟以太网对                        |
| MACVLAN     | `.macvlan`    | `macvlan`      | 基于 MAC 的虚拟局域网                |
| MACVTAP     | `.macvtap`    | `macvtap`      | 基于 MAC 的 TAP                    |
| TUN/TAP     | `.tuntap`     | `tuntap`       | TUN/TAP 设备                       |
| VXLAN       | `.vxlan`      | `vxlan`        | 虚拟可扩展局域网                     |
| IPVLAN      | `.ipvlan`     | `ipvlan`       | 基于 IP 的虚拟局域网                 |
| Bond        | `.bond`       | `bond`         | 链路聚合                            |
| Geneve      | `.geneve`     | `geneve`       | 通用网络虚拟化                       |
| GRE TAP     | `.gretap`     | `gretap`       | GRE 二层隧道                        |
| GRE Tunnel  | `.gretun`     | `gre`          | GRE 三层隧道                        |
| IP-in-IP    | `.iptun`      | `ipip`         | IPv4-in-IPv4 隧道                   |
| IP6TNL      | `.ip6tnl`     | `ip6tnl`       | IPv6 隧道                           |
| SIT         | `.sit`        | `sit`          | IPv6-in-IPv4 隧道                   |
| VTI         | `.vti`        | `vti`          | 虚拟隧道接口                         |
| VRF         | `.vrf`        | `vrf`          | 虚拟路由和转发                       |
| WireGuard   | `.wireguard`  | `wireguard`    | WireGuard 安全隧道                   |

## API 概览

| 模块      | 函数                    | 说明                                          |
|----------|------------------------|-----------------------------------------------|
| `link`   | `linkAdd`              | 创建新的网络接口                                 |
| `link`   | `linkDel`              | 按索引删除网络接口                                |
| `link`   | `linkList`             | 列出所有网络接口                                 |
| `link`   | `linkByName`           | 按名称查找接口                                   |
| `link`   | `linkByIndex`          | 按内核索引查找接口                                |
| `link`   | `linkSetUp`            | 启用接口                                        |
| `link`   | `linkSetDown`          | 禁用接口                                        |
| `link`   | `linkSetMTU`           | 设置接口 MTU                                    |
| `link`   | `linkSetName`          | 重命名接口                                      |
| `link`   | `linkSetMaster`        | 设置接口主设备（bridge/bond）                      |
| `link`   | `linkSetNoMaster`      | 从主设备移除接口                                  |
| `link`   | `linkSetARPOn`         | 启用 ARP                                       |
| `link`   | `linkSetARPOff`        | 禁用 ARP                                       |
| `link`   | `linkSetPromiscOn`     | 启用混杂模式                                     |
| `link`   | `linkSetPromiscOff`    | 禁用混杂模式                                     |
| `link`   | `linkSetHardwareAddr`  | 设置 MAC 地址                                   |
| `addr`   | `addrAdd`              | 为接口添加 IP 地址                                |
| `addr`   | `addrReplace`          | 添加或替换 IP 地址                                |
| `addr`   | `addrDel`              | 从接口移除 IP 地址                                |
| `addr`   | `addrList`             | 列出接口上的 IP 地址                              |
| `route`  | `routeAdd`             | 添加路由                                        |
| `route`  | `routeReplace`         | 添加或替换路由                                    |
| `route`  | `routeDel`             | 删除路由                                        |
| `route`  | `routeList`            | 按地址族列出路由                                  |
| `route`  | `routeListFiltered`    | 按接口过滤列出路由                                |
| `neigh`  | `neighAdd`             | 添加邻居表项                                     |
| `neigh`  | `neighSet`             | 添加或替换邻居表项                                |
| `neigh`  | `neighAppend`          | 追加邻居表项                                     |
| `neigh`  | `neighDel`             | 删除邻居表项                                     |
| `neigh`  | `neighList`            | 列出邻居表项                                     |
| `types`  | `parseIPNet`           | 解析 CIDR 字符串（例如 `"10.0.0.0/8"`）            |
| `types`  | `parseIP`              | 解析 IP 地址字符串                                |
| `types`  | `newIPNet`             | 创建主机掩码的 IPNet（/32 或 /128）                 |
| `types`  | `computeBroadcast`     | 计算子网的广播地址                                 |

## 系统要求

- **Linux** -- 本库使用 Linux netlink 接口，不支持其他操作系统。
- **Root 权限** -- 大多数修改网络配置的 netlink 操作需要 `CAP_NET_ADMIN` 权限或 root 访问。只读操作（列出接口、地址、路由、邻居）可能无需提升权限即可执行。
- **Zig 0.15+** -- 使用 Zig 0.15 构建和测试。`build.zig.zon` 中指定的最低版本为 0.14.0，但推荐使用 0.15+。

## 测试

使用提供的脚本运行完整测试套件：

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

集成测试会修改网络状态，需要 root 权限。脚本会在需要时自动使用 `sudo` 重新运行。

你也可以直接使用 Zig 运行测试：

```bash
zig build test
```

## 贡献

欢迎贡献。请在 GitHub 上提交 issue 或 pull request。

提交更改时：

1. 确保所有测试通过（`./test.sh`）
2. 遵循现有的代码风格和命名规范
3. 为新功能添加测试
4. 保持提交专注且描述清晰

## 安全

如果你发现安全漏洞，请通过邮件向维护者负责任地报告，而不是开启公开的 issue。

## 许可证

基于 [Apache License, Version 2.0](../../LICENSE) 授权。

Copyright Zoptia. All rights reserved.
