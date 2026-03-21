# zoptianetlink

**純粋な Zig 実装の Linux netlink ネットワーク管理ライブラリ -- [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English](../../README.md) | [简体中文](README.zh-CN.md) | [日本語] | [한국어](README.ko.md) | [Español](README.es.md) | [Português](README.pt-BR.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | [Русский](README.ru.md)

---

`zoptianetlink` は、Linux の netlink ソケットインターフェースへの直接的かつ型安全なアクセスを提供する、純粋な Zig 実装の netlink ライブラリです。ネットワークインターフェース、ルート、アドレス、ネイバーの管理に利用できます。iproute2 のプログラム的な代替として機能し、リンクの作成・削除、IP アドレスの割り当て、ルーティングテーブルの操作、ARP/NDP ネイバーエントリの更新など、Linux ネットワーク管理のあらゆる側面を、C 依存関係なし・外部コマンド呼び出しなしで、ネイティブな Zig コードから設定できます。本ライブラリは netlink ソケットプロトコル（NETLINK_ROUTE）を通じてカーネルと通信し、`ip link`、`ip addr`、`ip route`、`ip neigh` といったツールと同等の低レベル制御を、コンパイル時の安全性と構造化されたエラーハンドリングとともに提供します。

## 機能

### リンク管理（ネットワークインターフェース）

- `linkAdd` -- ネットワークインターフェースの作成（bridge、veth、vlan、dummy、bond、wireguard など）
- `linkDel` -- ネットワークインターフェースの削除
- `linkList` -- 全ネットワークインターフェースの属性詳細を含む一覧取得
- `linkByName` / `linkByIndex` -- 名前またはカーネルインデックスによるインターフェースの検索
- `linkSetUp` / `linkSetDown` -- インターフェースの有効化・無効化
- `linkSetMTU` -- インターフェースの MTU 変更
- `linkSetName` -- インターフェースの名前変更
- `linkSetMaster` / `linkSetNoMaster` -- マスターデバイス（bridge、bond）へのインターフェースの接続・切断
- `linkSetARPOn` / `linkSetARPOff` -- インターフェースの ARP 有効化・無効化
- `linkSetPromiscOn` / `linkSetPromiscOff` -- プロミスキャスモードの有効化・無効化
- `linkSetHardwareAddr` -- インターフェースの MAC アドレス設定

### アドレス管理（IP アドレス）

- `addrAdd` -- インターフェースへの IP アドレスの割り当て
- `addrReplace` -- インターフェース上の IP アドレスの追加または置換
- `addrDel` -- インターフェースからの IP アドレスの削除
- `addrList` -- インターフェース上の全 IP アドレスの一覧取得（アドレスファミリによるフィルタリング対応）

### ルート管理（ルーティングテーブル）

- `routeAdd` -- ルーティングテーブルへのルート追加
- `routeReplace` -- ルートの追加または置換
- `routeDel` -- ルーティングテーブルからのルート削除
- `routeList` -- 指定アドレスファミリの全ルート一覧取得
- `routeListFiltered` -- インターフェースインデックスによるルートのフィルタリング一覧取得

### ネイバー管理（ARP / NDP）

- `neighAdd` -- ネイバー（ARP/NDP）エントリの追加
- `neighSet` -- ネイバーエントリの追加または置換
- `neighAppend` -- ネイバーエントリの追記
- `neighDel` -- ネイバーエントリの削除
- `neighList` -- 全ネイバーエントリの一覧取得（インターフェースおよびアドレスファミリによるフィルタリング対応）

## クイックスタート

### 依存関係の追加

`build.zig.zon` に `zoptianetlink` を追加します：

```zig
.dependencies = .{
    .zoptianetlink = .{
        .url = "https://github.com/zoptia/zoptianetlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

続いて `build.zig` に以下を記述します：

```zig
const netlink_dep = b.dependency("zoptianetlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### 最小限の例

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

## 使用例

### リンク：ブリッジの作成と有効化

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

### アドレス：インターフェースへの IP アドレスの割り当て

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

### ルート：デフォルトゲートウェイの追加

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

### ネイバー：静的 ARP エントリの追加

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

## 対応リンクタイプ

| リンクタイプ  | 列挙値         | カーネル文字列   | 説明                              |
|-------------|---------------|----------------|-----------------------------------|
| Device      | `.device`     | `device`       | 物理ネットワークデバイス               |
| Dummy       | `.dummy`      | `dummy`        | ダミーインターフェース                 |
| IFB         | `.ifb`        | `ifb`          | 中間機能ブロック                      |
| Bridge      | `.bridge`     | `bridge`       | イーサネットブリッジ                   |
| VLAN        | `.vlan`       | `vlan`         | 802.1Q VLAN                       |
| Veth        | `.veth`       | `veth`         | 仮想イーサネットペア                   |
| MACVLAN     | `.macvlan`    | `macvlan`      | MAC ベースの仮想 LAN                 |
| MACVTAP     | `.macvtap`    | `macvtap`      | MAC ベースの TAP                    |
| TUN/TAP     | `.tuntap`     | `tuntap`       | TUN/TAP デバイス                    |
| VXLAN       | `.vxlan`      | `vxlan`        | 仮想拡張 LAN                        |
| IPVLAN      | `.ipvlan`     | `ipvlan`       | IP ベースの仮想 LAN                  |
| Bond        | `.bond`       | `bond`         | ボンディング（リンクアグリゲーション）     |
| Geneve      | `.geneve`     | `geneve`       | 汎用ネットワーク仮想化                 |
| GRE TAP     | `.gretap`     | `gretap`       | GRE L2 トンネル                     |
| GRE Tunnel  | `.gretun`     | `gre`          | GRE L3 トンネル                     |
| IP-in-IP    | `.iptun`      | `ipip`         | IPv4-in-IPv4 トンネル                |
| IP6TNL      | `.ip6tnl`     | `ip6tnl`       | IPv6 トンネル                        |
| SIT         | `.sit`        | `sit`          | IPv6-in-IPv4 トンネル                |
| VTI         | `.vti`        | `vti`          | 仮想トンネルインターフェース             |
| VRF         | `.vrf`        | `vrf`          | 仮想ルーティングおよびフォワーディング     |
| WireGuard   | `.wireguard`  | `wireguard`    | WireGuard セキュアトンネル             |

## API 概要

| モジュール  | 関数                     | 説明                                           |
|----------|-------------------------|------------------------------------------------|
| `link`   | `linkAdd`               | 新しいネットワークインターフェースの作成              |
| `link`   | `linkDel`               | インデックスによるネットワークインターフェースの削除     |
| `link`   | `linkList`              | 全ネットワークインターフェースの一覧取得              |
| `link`   | `linkByName`            | 名前によるインターフェースの検索                     |
| `link`   | `linkByIndex`           | カーネルインデックスによるインターフェースの検索        |
| `link`   | `linkSetUp`             | インターフェースの有効化                            |
| `link`   | `linkSetDown`           | インターフェースの無効化                            |
| `link`   | `linkSetMTU`            | インターフェースの MTU 設定                         |
| `link`   | `linkSetName`           | インターフェースの名前変更                          |
| `link`   | `linkSetMaster`         | マスターデバイスの設定（bridge/bond）                |
| `link`   | `linkSetNoMaster`       | マスターデバイスからの切断                          |
| `link`   | `linkSetARPOn`          | ARP の有効化                                     |
| `link`   | `linkSetARPOff`         | ARP の無効化                                     |
| `link`   | `linkSetPromiscOn`      | プロミスキャスモードの有効化                        |
| `link`   | `linkSetPromiscOff`     | プロミスキャスモードの無効化                        |
| `link`   | `linkSetHardwareAddr`   | MAC アドレスの設定                                |
| `addr`   | `addrAdd`               | インターフェースへの IP アドレスの追加               |
| `addr`   | `addrReplace`           | IP アドレスの追加または置換                         |
| `addr`   | `addrDel`               | インターフェースからの IP アドレスの削除              |
| `addr`   | `addrList`              | インターフェース上の IP アドレスの一覧取得            |
| `route`  | `routeAdd`              | ルートの追加                                      |
| `route`  | `routeReplace`          | ルートの追加または置換                              |
| `route`  | `routeDel`              | ルートの削除                                      |
| `route`  | `routeList`             | アドレスファミリ別のルート一覧取得                    |
| `route`  | `routeListFiltered`     | インターフェースによるルートのフィルタリング一覧取得    |
| `neigh`  | `neighAdd`              | ネイバーエントリの追加                              |
| `neigh`  | `neighSet`              | ネイバーエントリの追加または置換                     |
| `neigh`  | `neighAppend`           | ネイバーエントリの追記                              |
| `neigh`  | `neighDel`              | ネイバーエントリの削除                              |
| `neigh`  | `neighList`             | ネイバーエントリの一覧取得                          |
| `types`  | `parseIPNet`            | CIDR 文字列の解析（例: `"10.0.0.0/8"`）             |
| `types`  | `parseIP`               | IP アドレス文字列の解析                             |
| `types`  | `newIPNet`              | ホストマスク付き IPNet の作成（/32 または /128）       |
| `types`  | `computeBroadcast`      | サブネットのブロードキャストアドレスの計算              |

## システム要件

- **Linux** -- 本ライブラリは Linux の netlink インターフェースを使用しており、他のオペレーティングシステムには対応していません。
- **root 権限** -- ネットワーク設定を変更する netlink 操作の大半は `CAP_NET_ADMIN` 権限または root アクセスが必要です。読み取り専用の操作（インターフェース、アドレス、ルート、ネイバーの一覧取得）は権限昇格なしで実行できる場合があります。
- **Zig 0.15+** -- Zig 0.15 でビルドおよびテスト済み。`build.zig.zon` で指定されている最低バージョンは 0.14.0 ですが、0.15+ を推奨します。

## テスト

提供されているスクリプトを使用してテストスイート全体を実行します：

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

統合テストはネットワーク状態を変更するため、root 権限が必要です。スクリプトは必要に応じて自動的に `sudo` で再実行します。

Zig を直接使用してテストを実行することもできます：

```bash
zig build test
```

## コントリビューション

コントリビューションを歓迎します。GitHub で issue を開くか、pull request を提出してください。

変更を提出する際のガイドライン：

1. 全テストが通ることを確認してください（`./test.sh`）
2. 既存のコードスタイルと命名規則に従ってください
3. 新機能にはテストを追加してください
4. コミットは焦点を絞り、明確に記述してください

## セキュリティ

セキュリティ上の脆弱性を発見した場合は、公開 issue を作成するのではなく、メンテナーにメールで責任ある報告をお願いします。

## ライセンス

[Apache License, Version 2.0](../../LICENSE) の下でライセンスされています。

Copyright Zoptia. All rights reserved.
