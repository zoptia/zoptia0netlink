# zoptia0netlink

**Bibliothèque netlink en Zig pur pour la gestion réseau sous Linux -- [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English](../../README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Português](README.pt-BR.md) | [Deutsch](README.de.md) | [Français] | [Русский](README.ru.md)

---

`zoptia0netlink` est une bibliotheque netlink pour Zig qui fournit un acces direct et type-safe a l'interface de socket netlink de Linux pour gerer les interfaces reseau, les routes, les adresses et les voisins. Elle sert d'alternative programmatique a iproute2, vous permettant de configurer tous les aspects de la gestion reseau sous Linux -- creer et supprimer des liens, attribuer des adresses IP, manipuler les tables de routage et mettre a jour les entrees de voisins ARP/NDP -- le tout depuis du code natif en Zig sans dependances C et sans appels shell. La bibliotheque communique avec le noyau via le protocole de socket netlink (NETLINK_ROUTE), offrant le meme controle de bas niveau que des outils comme `ip link`, `ip addr`, `ip route` et `ip neigh`, mais avec une securite a la compilation et une gestion structuree des erreurs.

## Fonctionnalites

### Gestion des liens (Interfaces reseau)

- `linkAdd` -- Creer des interfaces reseau (bridge, veth, vlan, dummy, bond, wireguard et plus)
- `linkDel` -- Supprimer des interfaces reseau
- `linkList` -- Enumerer toutes les interfaces reseau avec les details complets des attributs
- `linkByName` / `linkByIndex` -- Rechercher une interface par nom ou index du noyau
- `linkSetUp` / `linkSetDown` -- Activer ou desactiver des interfaces
- `linkSetMTU` -- Modifier le MTU d'une interface
- `linkSetName` -- Renommer une interface
- `linkSetMaster` / `linkSetNoMaster` -- Attacher ou detacher une interface d'un maitre (bridge, bond)
- `linkSetARPOn` / `linkSetARPOff` -- Activer ou desactiver ARP sur une interface
- `linkSetPromiscOn` / `linkSetPromiscOff` -- Activer ou desactiver le mode promiscuous
- `linkSetHardwareAddr` -- Definir l'adresse MAC d'une interface

### Gestion des adresses (Adresses IP)

- `addrAdd` -- Attribuer une adresse IP a une interface
- `addrReplace` -- Ajouter ou remplacer une adresse IP sur une interface
- `addrDel` -- Supprimer une adresse IP d'une interface
- `addrList` -- Lister toutes les adresses IP d'une interface, filtrees par famille d'adresses

### Gestion des routes (Table de routage)

- `routeAdd` -- Ajouter une route a la table de routage
- `routeReplace` -- Ajouter ou remplacer une route
- `routeDel` -- Supprimer une route de la table de routage
- `routeList` -- Lister toutes les routes pour une famille d'adresses donnee
- `routeListFiltered` -- Lister les routes filtrees par index d'interface

### Gestion des voisins (ARP / NDP)

- `neighAdd` -- Ajouter une entree de voisin (ARP/NDP)
- `neighSet` -- Ajouter ou remplacer une entree de voisin
- `neighAppend` -- Annexer une entree de voisin
- `neighDel` -- Supprimer une entree de voisin
- `neighList` -- Lister toutes les entrees de voisins, filtrees par interface et famille d'adresses

## Demarrage rapide

### Ajouter la dependance

Ajoutez `zoptia0netlink` a votre `build.zig.zon` :

```zig
.dependencies = .{
    .zoptia0netlink = .{
        .url = "https://github.com/zoptia/zoptia0netlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

Puis dans votre `build.zig` :

```zig
const netlink_dep = b.dependency("zoptia0netlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### Exemple minimal

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

## Exemples d'utilisation

### Lien : Creer un bridge et l'activer

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

### Adresse : Attribuer une adresse IP a une interface

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

### Route : Ajouter une passerelle par defaut

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

### Voisin : Ajouter une entree ARP statique

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

## Types de liens pris en charge

| Type de lien   | Valeur enum    | Chaine du noyau   | Description                            |
|----------------|----------------|--------------------|----------------------------------------|
| Device         | `.device`      | `device`           | Peripherique reseau physique           |
| Dummy          | `.dummy`       | `dummy`            | Interface dummy                        |
| IFB            | `.ifb`         | `ifb`              | Bloc fonctionnel intermediaire         |
| Bridge         | `.bridge`      | `bridge`           | Pont Ethernet                          |
| VLAN           | `.vlan`        | `vlan`             | VLAN 802.1Q                            |
| Veth           | `.veth`        | `veth`             | Paire Ethernet virtuelle              |
| MACVLAN        | `.macvlan`     | `macvlan`          | LAN virtuel base sur MAC              |
| MACVTAP        | `.macvtap`     | `macvtap`          | TAP base sur MAC                       |
| TUN/TAP        | `.tuntap`      | `tuntap`           | Peripherique TUN/TAP                   |
| VXLAN          | `.vxlan`       | `vxlan`            | LAN extensible virtuel                 |
| IPVLAN         | `.ipvlan`      | `ipvlan`           | LAN virtuel base sur IP                |
| Bond           | `.bond`        | `bond`             | Bonding (agregation de liens)          |
| Geneve         | `.geneve`      | `geneve`           | Virtualisation de reseau generique     |
| GRE TAP        | `.gretap`      | `gretap`           | Tunnel GRE L2                          |
| GRE Tunnel     | `.gretun`      | `gre`              | Tunnel GRE L3                          |
| IP-in-IP       | `.iptun`       | `ipip`             | Tunnel IPv4-dans-IPv4                  |
| IP6TNL         | `.ip6tnl`      | `ip6tnl`           | Tunnel IPv6                            |
| SIT            | `.sit`         | `sit`              | Tunnel IPv6-dans-IPv4                  |
| VTI            | `.vti`         | `vti`              | Interface de tunnel virtuel            |
| VRF            | `.vrf`         | `vrf`              | Routage et transfert virtuels          |
| WireGuard      | `.wireguard`   | `wireguard`        | Tunnel securise WireGuard              |

## Apercu de l'API

| Module   | Fonction              | Description                                    |
|----------|-----------------------|------------------------------------------------|
| `link`   | `linkAdd`             | Creer une nouvelle interface reseau            |
| `link`   | `linkDel`             | Supprimer une interface reseau par index        |
| `link`   | `linkList`            | Lister toutes les interfaces reseau            |
| `link`   | `linkByName`          | Rechercher une interface par nom               |
| `link`   | `linkByIndex`         | Rechercher une interface par index du noyau    |
| `link`   | `linkSetUp`           | Activer une interface                          |
| `link`   | `linkSetDown`         | Desactiver une interface                       |
| `link`   | `linkSetMTU`          | Definir le MTU de l'interface                  |
| `link`   | `linkSetName`         | Renommer une interface                         |
| `link`   | `linkSetMaster`       | Definir le maitre de l'interface (bridge/bond) |
| `link`   | `linkSetNoMaster`     | Retirer l'interface du maitre                  |
| `link`   | `linkSetARPOn`        | Activer ARP                                    |
| `link`   | `linkSetARPOff`       | Desactiver ARP                                 |
| `link`   | `linkSetPromiscOn`    | Activer le mode promiscuous                    |
| `link`   | `linkSetPromiscOff`   | Desactiver le mode promiscuous                 |
| `link`   | `linkSetHardwareAddr` | Definir l'adresse MAC                          |
| `addr`   | `addrAdd`             | Ajouter une adresse IP a une interface         |
| `addr`   | `addrReplace`         | Ajouter ou remplacer une adresse IP            |
| `addr`   | `addrDel`             | Supprimer une adresse IP d'une interface       |
| `addr`   | `addrList`            | Lister les adresses IP d'une interface         |
| `route`  | `routeAdd`            | Ajouter une route                              |
| `route`  | `routeReplace`        | Ajouter ou remplacer une route                 |
| `route`  | `routeDel`            | Supprimer une route                            |
| `route`  | `routeList`           | Lister les routes par famille d'adresses       |
| `route`  | `routeListFiltered`   | Lister les routes filtrees par interface        |
| `neigh`  | `neighAdd`            | Ajouter une entree de voisin                   |
| `neigh`  | `neighSet`            | Ajouter ou remplacer une entree de voisin      |
| `neigh`  | `neighAppend`         | Annexer une entree de voisin                   |
| `neigh`  | `neighDel`            | Supprimer une entree de voisin                 |
| `neigh`  | `neighList`           | Lister les entrees de voisins                  |
| `types`  | `parseIPNet`          | Analyser une chaine CIDR (ex. `"10.0.0.0/8"`) |
| `types`  | `parseIP`             | Analyser une chaine d'adresse IP               |
| `types`  | `newIPNet`            | Creer un IPNet avec un masque d'hote (/32 ou /128) |
| `types`  | `computeBroadcast`    | Calculer l'adresse de broadcast d'un sous-reseau |

## Prerequis

- **Linux** -- Cette bibliotheque utilise l'interface netlink de Linux et n'est pas portable vers d'autres systemes d'exploitation.
- **Privileges root** -- La plupart des operations netlink qui modifient la configuration reseau necessitent `CAP_NET_ADMIN` ou un acces root. Les operations en lecture seule (lister les interfaces, adresses, routes, voisins) peuvent fonctionner sans privileges eleves.
- **Zig 0.15+** -- Construite et testee avec Zig 0.15. La version minimale specifiee dans `build.zig.zon` est 0.14.0, mais 0.15+ est recommande.

## Tests

Executez la suite de tests complete avec le script fourni :

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

Les tests d'integration modifient l'etat du reseau et necessitent des privileges root. Le script se relancera automatiquement avec `sudo` si necessaire.

Vous pouvez egalement executer les tests directement avec Zig :

```bash
zig build test
```

## Contribuer

Les contributions sont les bienvenues. Veuillez ouvrir un issue ou soumettre un pull request sur GitHub.

Lors de la soumission de modifications :

1. Assurez-vous que tous les tests passent (`./test.sh`)
2. Suivez le style de code et les conventions de nommage existants
3. Ajoutez des tests pour les nouvelles fonctionnalites
4. Gardez les commits cibles et bien decrits

## Securite

Si vous decouvrez une vulnerabilite de securite, veuillez la signaler de maniere responsable en envoyant un e-mail aux mainteneurs plutot qu'en ouvrant un issue public.

## Licence

Sous licence [Apache License, Version 2.0](LICENSE).

Copyright Zoptia. Tous droits reserves.
