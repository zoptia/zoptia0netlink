# ZoptiaNetlink

**순수 Zig로 구현한 Linux netlink 네트워크 관리 라이브러리 -- [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English](../../README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어] | [Español](README.es.md) | [Português](README.pt-BR.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | [Русский](README.ru.md)

---

`ZoptiaNetlink`는 Linux netlink 소켓 인터페이스에 대한 직접적이고 타입 안전한 접근을 제공하는 순수 Zig netlink 라이브러리입니다. 네트워크 인터페이스, 라우트, 주소, 이웃 테이블을 관리하는 데 사용할 수 있습니다. iproute2의 프로그래밍 대안으로서, 링크 생성 및 삭제, IP 주소 할당, 라우팅 테이블 조작, ARP/NDP 이웃 항목 업데이트 등 Linux 네트워크 관리의 모든 측면을 C 의존성 없이, 외부 명령 호출 없이, 네이티브 Zig 코드로 구성할 수 있습니다. 이 라이브러리는 netlink 소켓 프로토콜(NETLINK_ROUTE)을 통해 커널과 통신하며, `ip link`, `ip addr`, `ip route`, `ip neigh`와 같은 도구가 제공하는 것과 동일한 저수준 제어를 컴파일 시점 안전성과 구조화된 오류 처리와 함께 제공합니다.

## 기능

### 링크 관리 (네트워크 인터페이스)

- `linkAdd` -- 네트워크 인터페이스 생성 (bridge, veth, vlan, dummy, bond, wireguard 등)
- `linkDel` -- 네트워크 인터페이스 삭제
- `linkList` -- 모든 네트워크 인터페이스의 전체 속성 정보 조회
- `linkByName` / `linkByIndex` -- 이름 또는 커널 인덱스로 단일 인터페이스 검색
- `linkSetUp` / `linkSetDown` -- 인터페이스 활성화 또는 비활성화
- `linkSetMTU` -- 인터페이스의 MTU 변경
- `linkSetName` -- 인터페이스 이름 변경
- `linkSetMaster` / `linkSetNoMaster` -- 마스터 장치(bridge, bond)에 인터페이스 연결 또는 분리
- `linkSetARPOn` / `linkSetARPOff` -- 인터페이스의 ARP 활성화 또는 비활성화
- `linkSetPromiscOn` / `linkSetPromiscOff` -- 무차별 모드 활성화 또는 비활성화
- `linkSetHardwareAddr` -- 인터페이스의 MAC 주소 설정

### 주소 관리 (IP 주소)

- `addrAdd` -- 인터페이스에 IP 주소 할당
- `addrReplace` -- 인터페이스의 IP 주소 추가 또는 교체
- `addrDel` -- 인터페이스에서 IP 주소 제거
- `addrList` -- 인터페이스의 모든 IP 주소 조회 (주소 패밀리별 필터링 지원)

### 라우트 관리 (라우팅 테이블)

- `routeAdd` -- 라우팅 테이블에 라우트 추가
- `routeReplace` -- 라우트 추가 또는 교체
- `routeDel` -- 라우팅 테이블에서 라우트 삭제
- `routeList` -- 지정된 주소 패밀리의 모든 라우트 조회
- `routeListFiltered` -- 인터페이스 인덱스로 필터링한 라우트 조회

### 이웃 관리 (ARP / NDP)

- `neighAdd` -- 이웃(ARP/NDP) 항목 추가
- `neighSet` -- 이웃 항목 추가 또는 교체
- `neighAppend` -- 이웃 항목 추가(append)
- `neighDel` -- 이웃 항목 삭제
- `neighList` -- 모든 이웃 항목 조회 (인터페이스 및 주소 패밀리별 필터링 지원)

## 빠른 시작

### 의존성 추가

`build.zig.zon`에 `zoptianetlink`를 추가합니다:

```zig
.dependencies = .{
    .zoptianetlink = .{
        .url = "https://github.com/zoptia/zoptianetlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

그런 다음 `build.zig`에 다음을 추가합니다:

```zig
const netlink_dep = b.dependency("zoptianetlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### 최소 예제

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

## 사용 예제

### 링크: 브리지 생성 및 활성화

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

### 주소: 인터페이스에 IP 주소 할당

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

### 라우트: 기본 게이트웨이 추가

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

### 이웃: 정적 ARP 항목 추가

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

## 지원 링크 타입

| 링크 타입    | 열거형 값       | 커널 문자열      | 설명                              |
|-------------|---------------|----------------|-----------------------------------|
| Device      | `.device`     | `device`       | 물리적 네트워크 장치                  |
| Dummy       | `.dummy`      | `dummy`        | 더미 인터페이스                      |
| IFB         | `.ifb`        | `ifb`          | 중간 기능 블록                       |
| Bridge      | `.bridge`     | `bridge`       | 이더넷 브리지                        |
| VLAN        | `.vlan`       | `vlan`         | 802.1Q VLAN                       |
| Veth        | `.veth`       | `veth`         | 가상 이더넷 페어                     |
| MACVLAN     | `.macvlan`    | `macvlan`      | MAC 기반 가상 LAN                   |
| MACVTAP     | `.macvtap`    | `macvtap`      | MAC 기반 TAP                       |
| TUN/TAP     | `.tuntap`     | `tuntap`       | TUN/TAP 장치                       |
| VXLAN       | `.vxlan`      | `vxlan`        | 가상 확장 LAN                       |
| IPVLAN      | `.ipvlan`     | `ipvlan`       | IP 기반 가상 LAN                    |
| Bond        | `.bond`       | `bond`         | 본딩 (링크 집계)                     |
| Geneve      | `.geneve`     | `geneve`       | 범용 네트워크 가상화                  |
| GRE TAP     | `.gretap`     | `gretap`       | GRE L2 터널                        |
| GRE Tunnel  | `.gretun`     | `gre`          | GRE L3 터널                        |
| IP-in-IP    | `.iptun`      | `ipip`         | IPv4-in-IPv4 터널                   |
| IP6TNL      | `.ip6tnl`     | `ip6tnl`       | IPv6 터널                           |
| SIT         | `.sit`        | `sit`          | IPv6-in-IPv4 터널                   |
| VTI         | `.vti`        | `vti`          | 가상 터널 인터페이스                  |
| VRF         | `.vrf`        | `vrf`          | 가상 라우팅 및 포워딩                 |
| WireGuard   | `.wireguard`  | `wireguard`    | WireGuard 보안 터널                  |

## API 개요

| 모듈      | 함수                     | 설명                                           |
|----------|-------------------------|------------------------------------------------|
| `link`   | `linkAdd`               | 새 네트워크 인터페이스 생성                        |
| `link`   | `linkDel`               | 인덱스로 네트워크 인터페이스 삭제                    |
| `link`   | `linkList`              | 모든 네트워크 인터페이스 조회                       |
| `link`   | `linkByName`            | 이름으로 인터페이스 검색                           |
| `link`   | `linkByIndex`           | 커널 인덱스로 인터페이스 검색                       |
| `link`   | `linkSetUp`             | 인터페이스 활성화                                 |
| `link`   | `linkSetDown`           | 인터페이스 비활성화                                |
| `link`   | `linkSetMTU`            | 인터페이스 MTU 설정                               |
| `link`   | `linkSetName`           | 인터페이스 이름 변경                               |
| `link`   | `linkSetMaster`         | 마스터 장치 설정 (bridge/bond)                     |
| `link`   | `linkSetNoMaster`       | 마스터 장치에서 분리                               |
| `link`   | `linkSetARPOn`          | ARP 활성화                                      |
| `link`   | `linkSetARPOff`         | ARP 비활성화                                     |
| `link`   | `linkSetPromiscOn`      | 무차별 모드 활성화                                 |
| `link`   | `linkSetPromiscOff`     | 무차별 모드 비활성화                               |
| `link`   | `linkSetHardwareAddr`   | MAC 주소 설정                                    |
| `addr`   | `addrAdd`               | 인터페이스에 IP 주소 추가                          |
| `addr`   | `addrReplace`           | IP 주소 추가 또는 교체                             |
| `addr`   | `addrDel`               | 인터페이스에서 IP 주소 제거                         |
| `addr`   | `addrList`              | 인터페이스의 IP 주소 조회                           |
| `route`  | `routeAdd`              | 라우트 추가                                      |
| `route`  | `routeReplace`          | 라우트 추가 또는 교체                              |
| `route`  | `routeDel`              | 라우트 삭제                                      |
| `route`  | `routeList`             | 주소 패밀리별 라우트 조회                           |
| `route`  | `routeListFiltered`     | 인터페이스별 라우트 필터링 조회                      |
| `neigh`  | `neighAdd`              | 이웃 항목 추가                                    |
| `neigh`  | `neighSet`              | 이웃 항목 추가 또는 교체                            |
| `neigh`  | `neighAppend`           | 이웃 항목 추가(append)                             |
| `neigh`  | `neighDel`              | 이웃 항목 삭제                                    |
| `neigh`  | `neighList`             | 이웃 항목 조회                                    |
| `types`  | `parseIPNet`            | CIDR 문자열 파싱 (예: `"10.0.0.0/8"`)              |
| `types`  | `parseIP`               | IP 주소 문자열 파싱                                |
| `types`  | `newIPNet`              | 호스트 마스크 IPNet 생성 (/32 또는 /128)             |
| `types`  | `computeBroadcast`      | 서브넷의 브로드캐스트 주소 계산                      |

## 시스템 요구 사항

- **Linux** -- 이 라이브러리는 Linux netlink 인터페이스를 사용하며 다른 운영체제에서는 사용할 수 없습니다.
- **root 권한** -- 네트워크 설정을 변경하는 대부분의 netlink 작업에는 `CAP_NET_ADMIN` 또는 root 접근 권한이 필요합니다. 읽기 전용 작업(인터페이스, 주소, 라우트, 이웃 조회)은 권한 상승 없이도 동작할 수 있습니다.
- **Zig 0.15+** -- Zig 0.15로 빌드 및 테스트되었습니다. `build.zig.zon`에 명시된 최소 버전은 0.14.0이지만, 0.15+ 사용을 권장합니다.

## 테스트

제공된 스크립트를 사용하여 전체 테스트 스위트를 실행합니다:

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

통합 테스트는 네트워크 상태를 변경하므로 root 권한이 필요합니다. 스크립트는 필요 시 자동으로 `sudo`를 사용하여 다시 실행합니다.

Zig를 직접 사용하여 테스트를 실행할 수도 있습니다:

```bash
zig build test
```

## 기여

기여를 환영합니다. GitHub에서 issue를 열거나 pull request를 제출해 주세요.

변경 사항 제출 시:

1. 모든 테스트가 통과하는지 확인하세요 (`./test.sh`)
2. 기존 코드 스타일과 네이밍 규칙을 따라 주세요
3. 새로운 기능에는 테스트를 추가해 주세요
4. 커밋은 집중적이고 명확하게 기술해 주세요

## 보안

보안 취약점을 발견한 경우, 공개 issue를 열지 말고 메인테이너에게 이메일로 책임감 있게 보고해 주세요.

## 라이선스

[Apache License, Version 2.0](../../LICENSE)에 따라 라이선스됩니다.

Copyright Zoptia. All rights reserved.
