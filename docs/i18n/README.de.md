# zoptianetlink

**Eine reine Zig-Bibliothek für Linux-Netzwerkverwaltung über Netlink -- [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English](../../README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Português](README.pt-BR.md) | [Deutsch] | [Français](README.fr.md) | [Русский](README.ru.md)

---

`zoptianetlink` ist eine Zig-Netlink-Bibliothek, die direkten, typsicheren Zugriff auf die Linux-Netlink-Socket-Schnittstelle zur Verwaltung von Netzwerkschnittstellen, Routen, Adressen und Nachbarn bietet. Sie dient als programmatische Alternative zu iproute2 und ermoeglicht die Konfiguration aller Aspekte der Linux-Netzwerkverwaltung -- Erstellen und Loeschen von Links, Zuweisen von IP-Adressen, Manipulation von Routing-Tabellen und Aktualisierung von ARP/NDP-Nachbareintraegen -- alles aus nativem Zig-Code ohne C-Abhaengigkeiten und ohne Shell-Aufrufe. Die Bibliothek kommuniziert mit dem Kernel ueber das Netlink-Socket-Protokoll (NETLINK_ROUTE) und bietet die gleiche Low-Level-Kontrolle wie Werkzeuge wie `ip link`, `ip addr`, `ip route` und `ip neigh`, jedoch mit Compile-Zeit-Sicherheit und strukturierter Fehlerbehandlung.

## Funktionen

### Link-Verwaltung (Netzwerkschnittstellen)

- `linkAdd` -- Netzwerkschnittstellen erstellen (bridge, veth, vlan, dummy, bond, wireguard und mehr)
- `linkDel` -- Netzwerkschnittstellen loeschen
- `linkList` -- Alle Netzwerkschnittstellen mit vollstaendigen Attributdetails auflisten
- `linkByName` / `linkByIndex` -- Eine einzelne Schnittstelle nach Name oder Kernel-Index suchen
- `linkSetUp` / `linkSetDown` -- Schnittstellen aktivieren oder deaktivieren
- `linkSetMTU` -- Die MTU einer Schnittstelle aendern
- `linkSetName` -- Eine Schnittstelle umbenennen
- `linkSetMaster` / `linkSetNoMaster` -- Eine Schnittstelle an einen Master (bridge, bond) anbinden oder loesen
- `linkSetARPOn` / `linkSetARPOff` -- ARP auf einer Schnittstelle aktivieren oder deaktivieren
- `linkSetPromiscOn` / `linkSetPromiscOff` -- Promiscuous-Modus aktivieren oder deaktivieren
- `linkSetHardwareAddr` -- Die MAC-Adresse einer Schnittstelle setzen

### Adressverwaltung (IP-Adressen)

- `addrAdd` -- Eine IP-Adresse einer Schnittstelle zuweisen
- `addrReplace` -- Eine IP-Adresse auf einer Schnittstelle hinzufuegen oder ersetzen
- `addrDel` -- Eine IP-Adresse von einer Schnittstelle entfernen
- `addrList` -- Alle IP-Adressen einer Schnittstelle auflisten, gefiltert nach Adressfamilie

### Routenverwaltung (Routing-Tabelle)

- `routeAdd` -- Eine Route zur Routing-Tabelle hinzufuegen
- `routeReplace` -- Eine Route hinzufuegen oder ersetzen
- `routeDel` -- Eine Route aus der Routing-Tabelle loeschen
- `routeList` -- Alle Routen fuer eine gegebene Adressfamilie auflisten
- `routeListFiltered` -- Routen gefiltert nach Schnittstellenindex auflisten

### Nachbarverwaltung (ARP / NDP)

- `neighAdd` -- Einen Nachbareintrag (ARP/NDP) hinzufuegen
- `neighSet` -- Einen Nachbareintrag hinzufuegen oder ersetzen
- `neighAppend` -- Einen Nachbareintrag anfuegen
- `neighDel` -- Einen Nachbareintrag loeschen
- `neighList` -- Alle Nachbareintraege auflisten, gefiltert nach Schnittstelle und Adressfamilie

## Schnellstart

### Abhaengigkeit hinzufuegen

Fuege `zoptianetlink` zu deiner `build.zig.zon` hinzu:

```zig
.dependencies = .{
    .zoptianetlink = .{
        .url = "https://github.com/zoptia/zoptianetlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

Dann in deiner `build.zig`:

```zig
const netlink_dep = b.dependency("zoptianetlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### Minimales Beispiel

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

## Verwendungsbeispiele

### Link: Eine Bridge erstellen und aktivieren

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

### Adresse: Eine IP-Adresse einer Schnittstelle zuweisen

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

### Route: Ein Standard-Gateway hinzufuegen

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

### Nachbar: Einen statischen ARP-Eintrag hinzufuegen

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

## Unterstuetzte Link-Typen

| Link-Typ       | Enum-Wert      | Kernel-String     | Beschreibung                           |
|----------------|----------------|-------------------|----------------------------------------|
| Device         | `.device`      | `device`          | Physisches Netzwerkgeraet              |
| Dummy          | `.dummy`       | `dummy`           | Dummy-Schnittstelle                    |
| IFB            | `.ifb`         | `ifb`             | Intermediate Functional Block          |
| Bridge         | `.bridge`      | `bridge`          | Ethernet-Bridge                        |
| VLAN           | `.vlan`        | `vlan`            | 802.1Q VLAN                            |
| Veth           | `.veth`        | `veth`            | Virtuelles Ethernet-Paar              |
| MACVLAN        | `.macvlan`     | `macvlan`         | MAC-basiertes virtuelles LAN           |
| MACVTAP        | `.macvtap`     | `macvtap`         | MAC-basierter TAP                      |
| TUN/TAP        | `.tuntap`      | `tuntap`          | TUN/TAP-Geraet                         |
| VXLAN          | `.vxlan`       | `vxlan`           | Virtual Extensible LAN                 |
| IPVLAN         | `.ipvlan`      | `ipvlan`          | IP-basiertes virtuelles LAN            |
| Bond           | `.bond`        | `bond`            | Bonding (Link-Aggregation)             |
| Geneve         | `.geneve`      | `geneve`          | Generische Netzwerkvirtualisierung     |
| GRE TAP        | `.gretap`      | `gretap`          | GRE-L2-Tunnel                          |
| GRE Tunnel     | `.gretun`      | `gre`             | GRE-L3-Tunnel                          |
| IP-in-IP       | `.iptun`       | `ipip`            | IPv4-in-IPv4-Tunnel                    |
| IP6TNL         | `.ip6tnl`      | `ip6tnl`          | IPv6-Tunnel                            |
| SIT            | `.sit`         | `sit`             | IPv6-in-IPv4-Tunnel                    |
| VTI            | `.vti`         | `vti`             | Virtuelle Tunnel-Schnittstelle         |
| VRF            | `.vrf`         | `vrf`             | Virtuelles Routing und Forwarding      |
| WireGuard      | `.wireguard`   | `wireguard`       | Sicherer WireGuard-Tunnel              |

## API-Uebersicht

| Modul    | Funktion              | Beschreibung                                   |
|----------|-----------------------|------------------------------------------------|
| `link`   | `linkAdd`             | Eine neue Netzwerkschnittstelle erstellen       |
| `link`   | `linkDel`             | Eine Netzwerkschnittstelle nach Index loeschen  |
| `link`   | `linkList`            | Alle Netzwerkschnittstellen auflisten           |
| `link`   | `linkByName`          | Eine Schnittstelle nach Name suchen             |
| `link`   | `linkByIndex`         | Eine Schnittstelle nach Kernel-Index suchen     |
| `link`   | `linkSetUp`           | Eine Schnittstelle aktivieren                   |
| `link`   | `linkSetDown`         | Eine Schnittstelle deaktivieren                 |
| `link`   | `linkSetMTU`          | MTU der Schnittstelle setzen                    |
| `link`   | `linkSetName`         | Eine Schnittstelle umbenennen                   |
| `link`   | `linkSetMaster`       | Schnittstellen-Master setzen (bridge/bond)      |
| `link`   | `linkSetNoMaster`     | Schnittstelle vom Master loesen                 |
| `link`   | `linkSetARPOn`        | ARP aktivieren                                  |
| `link`   | `linkSetARPOff`       | ARP deaktivieren                                |
| `link`   | `linkSetPromiscOn`    | Promiscuous-Modus aktivieren                    |
| `link`   | `linkSetPromiscOff`   | Promiscuous-Modus deaktivieren                  |
| `link`   | `linkSetHardwareAddr` | MAC-Adresse setzen                              |
| `addr`   | `addrAdd`             | Eine IP-Adresse zu einer Schnittstelle hinzufuegen |
| `addr`   | `addrReplace`         | Eine IP-Adresse hinzufuegen oder ersetzen       |
| `addr`   | `addrDel`             | Eine IP-Adresse von einer Schnittstelle entfernen |
| `addr`   | `addrList`            | IP-Adressen einer Schnittstelle auflisten       |
| `route`  | `routeAdd`            | Eine Route hinzufuegen                          |
| `route`  | `routeReplace`        | Eine Route hinzufuegen oder ersetzen            |
| `route`  | `routeDel`            | Eine Route loeschen                             |
| `route`  | `routeList`           | Routen nach Adressfamilie auflisten             |
| `route`  | `routeListFiltered`   | Routen gefiltert nach Schnittstelle auflisten   |
| `neigh`  | `neighAdd`            | Einen Nachbareintrag hinzufuegen                |
| `neigh`  | `neighSet`            | Einen Nachbareintrag hinzufuegen oder ersetzen  |
| `neigh`  | `neighAppend`         | Einen Nachbareintrag anfuegen                   |
| `neigh`  | `neighDel`            | Einen Nachbareintrag loeschen                   |
| `neigh`  | `neighList`           | Nachbareintraege auflisten                      |
| `types`  | `parseIPNet`          | Einen CIDR-String parsen (z.B. `"10.0.0.0/8"`) |
| `types`  | `parseIP`             | Einen IP-Adressen-String parsen                 |
| `types`  | `newIPNet`            | Ein IPNet mit Host-Maske erstellen (/32 oder /128) |
| `types`  | `computeBroadcast`    | Die Broadcast-Adresse fuer ein Subnetz berechnen |

## Voraussetzungen

- **Linux** -- Diese Bibliothek nutzt die Linux-Netlink-Schnittstelle und ist nicht auf andere Betriebssysteme portierbar.
- **Root-Rechte** -- Die meisten Netlink-Operationen, die die Netzwerkkonfiguration aendern, erfordern `CAP_NET_ADMIN` oder Root-Zugriff. Nur-Lese-Operationen (Auflisten von Schnittstellen, Adressen, Routen, Nachbarn) koennen ohne erhoehte Rechte funktionieren.
- **Zig 0.15+** -- Erstellt und getestet mit Zig 0.15. Die in `build.zig.zon` angegebene Mindestversion ist 0.14.0, aber 0.15+ wird empfohlen.

## Tests

Fuehre die vollstaendige Testsuite mit dem bereitgestellten Skript aus:

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

Integrationstests aendern den Netzwerkzustand und erfordern Root-Rechte. Das Skript wird bei Bedarf automatisch mit `sudo` erneut ausgefuehrt.

Du kannst die Tests auch direkt mit Zig ausfuehren:

```bash
zig build test
```

## Mitwirken

Beitraege sind willkommen. Bitte oeffne ein Issue oder reiche einen Pull Request auf GitHub ein.

Beim Einreichen von Aenderungen:

1. Stelle sicher, dass alle Tests bestehen (`./test.sh`)
2. Folge dem bestehenden Code-Stil und den Namenskonventionen
3. Fuege Tests fuer neue Funktionalitaet hinzu
4. Halte Commits fokussiert und gut beschrieben

## Sicherheit

Wenn du eine Sicherheitsluecke entdeckst, melde sie bitte verantwortungsvoll per E-Mail an die Maintainer, anstatt ein oeffentliches Issue zu oeffnen.

## Lizenz

Lizenziert unter der [Apache-Lizenz, Version 2.0](LICENSE).

Copyright Zoptia. Alle Rechte vorbehalten.
