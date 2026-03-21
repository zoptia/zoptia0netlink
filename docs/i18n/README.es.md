# ZoptiaNetlink

**Biblioteca netlink en Zig puro para la gestión de redes en Linux -- [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English](../../README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español] | [Português](README.pt-BR.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | [Русский](README.ru.md)

---

`ZoptiaNetlink` es una biblioteca netlink para Zig que proporciona acceso directo y con tipado seguro a la interfaz de socket netlink de Linux para gestionar interfaces de red, rutas, direcciones y vecinos. Funciona como una alternativa programatica a iproute2, permitiendo configurar todos los aspectos de la gestion de redes en Linux -- crear y eliminar enlaces, asignar direcciones IP, manipular tablas de enrutamiento y actualizar entradas de vecinos ARP/NDP -- todo desde codigo nativo en Zig sin dependencias de C y sin llamadas a shell. La biblioteca se comunica con el kernel a traves del protocolo de socket netlink (NETLINK_ROUTE), otorgando el mismo control de bajo nivel que herramientas como `ip link`, `ip addr`, `ip route` e `ip neigh`, pero con seguridad en tiempo de compilacion y manejo estructurado de errores.

## Caracteristicas

### Gestion de enlaces (Interfaces de red)

- `linkAdd` -- Crear interfaces de red (bridge, veth, vlan, dummy, bond, wireguard y mas)
- `linkDel` -- Eliminar interfaces de red
- `linkList` -- Enumerar todas las interfaces de red con detalles completos de atributos
- `linkByName` / `linkByIndex` -- Buscar una interfaz individual por nombre o indice del kernel
- `linkSetUp` / `linkSetDown` -- Activar o desactivar interfaces
- `linkSetMTU` -- Cambiar el MTU de una interfaz
- `linkSetName` -- Renombrar una interfaz
- `linkSetMaster` / `linkSetNoMaster` -- Vincular o desvincular una interfaz de un maestro (bridge, bond)
- `linkSetARPOn` / `linkSetARPOff` -- Activar o desactivar ARP en una interfaz
- `linkSetPromiscOn` / `linkSetPromiscOff` -- Activar o desactivar el modo promiscuo
- `linkSetHardwareAddr` -- Establecer la direccion MAC de una interfaz

### Gestion de direcciones (Direcciones IP)

- `addrAdd` -- Asignar una direccion IP a una interfaz
- `addrReplace` -- Agregar o reemplazar una direccion IP en una interfaz
- `addrDel` -- Eliminar una direccion IP de una interfaz
- `addrList` -- Listar todas las direcciones IP de una interfaz, filtradas por familia de direcciones

### Gestion de rutas (Tabla de enrutamiento)

- `routeAdd` -- Agregar una ruta a la tabla de enrutamiento
- `routeReplace` -- Agregar o reemplazar una ruta
- `routeDel` -- Eliminar una ruta de la tabla de enrutamiento
- `routeList` -- Listar todas las rutas para una familia de direcciones dada
- `routeListFiltered` -- Listar rutas filtradas por indice de interfaz

### Gestion de vecinos (ARP / NDP)

- `neighAdd` -- Agregar una entrada de vecino (ARP/NDP)
- `neighSet` -- Agregar o reemplazar una entrada de vecino
- `neighAppend` -- Anexar una entrada de vecino
- `neighDel` -- Eliminar una entrada de vecino
- `neighList` -- Listar todas las entradas de vecinos, filtradas por interfaz y familia de direcciones

## Inicio rapido

### Agregar la dependencia

Agrega `zoptianetlink` a tu `build.zig.zon`:

```zig
.dependencies = .{
    .zoptianetlink = .{
        .url = "https://github.com/zoptia/zoptianetlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

Luego en tu `build.zig`:

```zig
const netlink_dep = b.dependency("zoptianetlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### Ejemplo minimo

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

## Ejemplos de uso

### Enlace: Crear un bridge y activarlo

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

### Direccion: Asignar una direccion IP a una interfaz

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

### Ruta: Agregar una puerta de enlace predeterminada

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

### Vecino: Agregar una entrada ARP estatica

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

## Tipos de enlace soportados

| Tipo de enlace | Valor del enum | Cadena del kernel | Descripcion                            |
|----------------|----------------|-------------------|----------------------------------------|
| Device         | `.device`      | `device`          | Dispositivo de red fisico              |
| Dummy          | `.dummy`       | `dummy`           | Interfaz dummy                         |
| IFB            | `.ifb`         | `ifb`             | Bloque funcional intermedio            |
| Bridge         | `.bridge`      | `bridge`          | Puente Ethernet                        |
| VLAN           | `.vlan`        | `vlan`            | VLAN 802.1Q                            |
| Veth           | `.veth`        | `veth`            | Par Ethernet virtual                   |
| MACVLAN        | `.macvlan`     | `macvlan`         | LAN virtual basada en MAC              |
| MACVTAP        | `.macvtap`     | `macvtap`         | TAP basado en MAC                      |
| TUN/TAP        | `.tuntap`      | `tuntap`          | Dispositivo TUN/TAP                    |
| VXLAN          | `.vxlan`       | `vxlan`           | LAN extensible virtual                 |
| IPVLAN         | `.ipvlan`      | `ipvlan`          | LAN virtual basada en IP               |
| Bond           | `.bond`        | `bond`            | Bonding (agregacion de enlaces)        |
| Geneve         | `.geneve`      | `geneve`          | Virtualizacion de red generica         |
| GRE TAP        | `.gretap`      | `gretap`          | Tunel GRE L2                           |
| GRE Tunnel     | `.gretun`      | `gre`             | Tunel GRE L3                           |
| IP-in-IP       | `.iptun`       | `ipip`            | Tunel IPv4-en-IPv4                     |
| IP6TNL         | `.ip6tnl`      | `ip6tnl`          | Tunel IPv6                             |
| SIT            | `.sit`         | `sit`             | Tunel IPv6-en-IPv4                     |
| VTI            | `.vti`         | `vti`             | Interfaz de tunel virtual              |
| VRF            | `.vrf`         | `vrf`             | Enrutamiento y reenvio virtual         |
| WireGuard      | `.wireguard`   | `wireguard`       | Tunel seguro WireGuard                 |

## Resumen de la API

| Modulo   | Funcion               | Descripcion                                    |
|----------|-----------------------|------------------------------------------------|
| `link`   | `linkAdd`             | Crear una nueva interfaz de red                |
| `link`   | `linkDel`             | Eliminar una interfaz de red por indice        |
| `link`   | `linkList`            | Listar todas las interfaces de red             |
| `link`   | `linkByName`          | Buscar una interfaz por nombre                 |
| `link`   | `linkByIndex`         | Buscar una interfaz por indice del kernel      |
| `link`   | `linkSetUp`           | Activar una interfaz                           |
| `link`   | `linkSetDown`         | Desactivar una interfaz                        |
| `link`   | `linkSetMTU`          | Establecer el MTU de la interfaz               |
| `link`   | `linkSetName`         | Renombrar una interfaz                         |
| `link`   | `linkSetMaster`       | Establecer maestro de interfaz (bridge/bond)   |
| `link`   | `linkSetNoMaster`     | Eliminar interfaz del maestro                  |
| `link`   | `linkSetARPOn`        | Activar ARP                                    |
| `link`   | `linkSetARPOff`       | Desactivar ARP                                 |
| `link`   | `linkSetPromiscOn`    | Activar modo promiscuo                         |
| `link`   | `linkSetPromiscOff`   | Desactivar modo promiscuo                      |
| `link`   | `linkSetHardwareAddr` | Establecer direccion MAC                       |
| `addr`   | `addrAdd`             | Agregar una direccion IP a una interfaz        |
| `addr`   | `addrReplace`         | Agregar o reemplazar una direccion IP          |
| `addr`   | `addrDel`             | Eliminar una direccion IP de una interfaz      |
| `addr`   | `addrList`            | Listar direcciones IP de una interfaz          |
| `route`  | `routeAdd`            | Agregar una ruta                               |
| `route`  | `routeReplace`        | Agregar o reemplazar una ruta                  |
| `route`  | `routeDel`            | Eliminar una ruta                              |
| `route`  | `routeList`           | Listar rutas por familia de direcciones        |
| `route`  | `routeListFiltered`   | Listar rutas filtradas por interfaz            |
| `neigh`  | `neighAdd`            | Agregar una entrada de vecino                  |
| `neigh`  | `neighSet`            | Agregar o reemplazar una entrada de vecino     |
| `neigh`  | `neighAppend`         | Anexar una entrada de vecino                   |
| `neigh`  | `neighDel`            | Eliminar una entrada de vecino                 |
| `neigh`  | `neighList`           | Listar entradas de vecinos                     |
| `types`  | `parseIPNet`          | Analizar una cadena CIDR (ej. `"10.0.0.0/8"`) |
| `types`  | `parseIP`             | Analizar una cadena de direccion IP            |
| `types`  | `newIPNet`            | Crear un IPNet con mascara de host (/32 o /128)|
| `types`  | `computeBroadcast`    | Calcular la direccion de broadcast de una subred|

## Requisitos

- **Linux** -- Esta biblioteca utiliza la interfaz netlink de Linux y no es portable a otros sistemas operativos.
- **Privilegios de root** -- La mayoria de las operaciones netlink que modifican la configuracion de red requieren `CAP_NET_ADMIN` o acceso root. Las operaciones de solo lectura (listar interfaces, direcciones, rutas, vecinos) pueden funcionar sin privilegios elevados.
- **Zig 0.15+** -- Construida y probada con Zig 0.15. La version minima especificada en `build.zig.zon` es 0.14.0, pero se recomienda 0.15+.

## Pruebas

Ejecuta el conjunto completo de pruebas usando el script proporcionado:

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

Las pruebas de integracion modifican el estado de la red y requieren privilegios de root. El script automaticamente se volvera a ejecutar con `sudo` si es necesario.

Tambien puedes ejecutar las pruebas directamente con Zig:

```bash
zig build test
```

## Contribuciones

Las contribuciones son bienvenidas. Por favor, abre un issue o envia un pull request en GitHub.

Al enviar cambios:

1. Asegurate de que todas las pruebas pasen (`./test.sh`)
2. Sigue el estilo de codigo y las convenciones de nomenclatura existentes
3. Agrega pruebas para la nueva funcionalidad
4. Mantiene los commits enfocados y bien descritos

## Seguridad

Si descubres una vulnerabilidad de seguridad, por favor reportala de manera responsable enviando un correo electronico a los mantenedores en lugar de abrir un issue publico.

## Licencia

Licenciado bajo la [Licencia Apache, Version 2.0](LICENSE).

Copyright Zoptia. Todos los derechos reservados.
