# ZoptiaNetlink

**Biblioteca netlink em Zig puro para gerenciamento de redes no Linux -- [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English](../../README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Português] | [Deutsch](README.de.md) | [Français](README.fr.md) | [Русский](README.ru.md)

---

`ZoptiaNetlink` e uma biblioteca netlink para Zig que fornece acesso direto e com tipagem segura a interface de socket netlink do Linux para gerenciar interfaces de rede, rotas, enderecos e vizinhos. Ela funciona como uma alternativa programatica ao iproute2, permitindo configurar todos os aspectos do gerenciamento de rede no Linux -- criar e deletar links, atribuir enderecos IP, manipular tabelas de roteamento e atualizar entradas de vizinhos ARP/NDP -- tudo a partir de codigo nativo em Zig, sem dependencias de C e sem chamadas ao shell. A biblioteca se comunica com o kernel atraves do protocolo de socket netlink (NETLINK_ROUTE), oferecendo o mesmo controle de baixo nivel que ferramentas como `ip link`, `ip addr`, `ip route` e `ip neigh`, mas com seguranca em tempo de compilacao e tratamento estruturado de erros.

## Funcionalidades

### Gerenciamento de links (Interfaces de rede)

- `linkAdd` -- Criar interfaces de rede (bridge, veth, vlan, dummy, bond, wireguard e mais)
- `linkDel` -- Deletar interfaces de rede
- `linkList` -- Enumerar todas as interfaces de rede com detalhes completos de atributos
- `linkByName` / `linkByIndex` -- Buscar uma interface individual por nome ou indice do kernel
- `linkSetUp` / `linkSetDown` -- Ativar ou desativar interfaces
- `linkSetMTU` -- Alterar o MTU de uma interface
- `linkSetName` -- Renomear uma interface
- `linkSetMaster` / `linkSetNoMaster` -- Vincular ou desvincular uma interface de um mestre (bridge, bond)
- `linkSetARPOn` / `linkSetARPOff` -- Ativar ou desativar ARP em uma interface
- `linkSetPromiscOn` / `linkSetPromiscOff` -- Ativar ou desativar o modo promiscuo
- `linkSetHardwareAddr` -- Definir o endereco MAC de uma interface

### Gerenciamento de enderecos (Enderecos IP)

- `addrAdd` -- Atribuir um endereco IP a uma interface
- `addrReplace` -- Adicionar ou substituir um endereco IP em uma interface
- `addrDel` -- Remover um endereco IP de uma interface
- `addrList` -- Listar todos os enderecos IP de uma interface, filtrados por familia de enderecos

### Gerenciamento de rotas (Tabela de roteamento)

- `routeAdd` -- Adicionar uma rota a tabela de roteamento
- `routeReplace` -- Adicionar ou substituir uma rota
- `routeDel` -- Deletar uma rota da tabela de roteamento
- `routeList` -- Listar todas as rotas para uma familia de enderecos
- `routeListFiltered` -- Listar rotas filtradas por indice de interface

### Gerenciamento de vizinhos (ARP / NDP)

- `neighAdd` -- Adicionar uma entrada de vizinho (ARP/NDP)
- `neighSet` -- Adicionar ou substituir uma entrada de vizinho
- `neighAppend` -- Anexar uma entrada de vizinho
- `neighDel` -- Deletar uma entrada de vizinho
- `neighList` -- Listar todas as entradas de vizinhos, filtradas por interface e familia de enderecos

## Inicio rapido

### Adicionar a dependencia

Adicione `zoptianetlink` ao seu `build.zig.zon`:

```zig
.dependencies = .{
    .zoptianetlink = .{
        .url = "https://github.com/zoptia/zoptianetlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

Em seguida, no seu `build.zig`:

```zig
const netlink_dep = b.dependency("zoptianetlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### Exemplo minimo

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

## Exemplos de uso

### Link: Criar um bridge e ativa-lo

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

### Endereco: Atribuir um endereco IP a uma interface

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

### Rota: Adicionar um gateway padrao

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

### Vizinho: Adicionar uma entrada ARP estatica

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

## Tipos de link suportados

| Tipo de link   | Valor do enum  | String do kernel  | Descricao                              |
|----------------|----------------|-------------------|----------------------------------------|
| Device         | `.device`      | `device`          | Dispositivo de rede fisico             |
| Dummy          | `.dummy`       | `dummy`           | Interface dummy                        |
| IFB            | `.ifb`         | `ifb`             | Bloco funcional intermediario          |
| Bridge         | `.bridge`      | `bridge`          | Ponte Ethernet                         |
| VLAN           | `.vlan`        | `vlan`            | VLAN 802.1Q                            |
| Veth           | `.veth`        | `veth`            | Par Ethernet virtual                   |
| MACVLAN        | `.macvlan`     | `macvlan`         | LAN virtual baseada em MAC             |
| MACVTAP        | `.macvtap`     | `macvtap`         | TAP baseado em MAC                     |
| TUN/TAP        | `.tuntap`      | `tuntap`          | Dispositivo TUN/TAP                    |
| VXLAN          | `.vxlan`       | `vxlan`           | LAN extensivel virtual                 |
| IPVLAN         | `.ipvlan`      | `ipvlan`          | LAN virtual baseada em IP              |
| Bond           | `.bond`        | `bond`            | Bonding (agregacao de links)           |
| Geneve         | `.geneve`      | `geneve`          | Virtualizacao de rede generica         |
| GRE TAP        | `.gretap`      | `gretap`          | Tunel GRE L2                           |
| GRE Tunnel     | `.gretun`      | `gre`             | Tunel GRE L3                           |
| IP-in-IP       | `.iptun`       | `ipip`            | Tunel IPv4-em-IPv4                     |
| IP6TNL         | `.ip6tnl`      | `ip6tnl`          | Tunel IPv6                             |
| SIT            | `.sit`         | `sit`             | Tunel IPv6-em-IPv4                     |
| VTI            | `.vti`         | `vti`             | Interface de tunel virtual             |
| VRF            | `.vrf`         | `vrf`             | Roteamento e encaminhamento virtual    |
| WireGuard      | `.wireguard`   | `wireguard`       | Tunel seguro WireGuard                 |

## Visao geral da API

| Modulo   | Funcao                | Descricao                                      |
|----------|-----------------------|------------------------------------------------|
| `link`   | `linkAdd`             | Criar uma nova interface de rede               |
| `link`   | `linkDel`             | Deletar uma interface de rede por indice       |
| `link`   | `linkList`            | Listar todas as interfaces de rede             |
| `link`   | `linkByName`          | Buscar uma interface por nome                  |
| `link`   | `linkByIndex`         | Buscar uma interface por indice do kernel      |
| `link`   | `linkSetUp`           | Ativar uma interface                           |
| `link`   | `linkSetDown`         | Desativar uma interface                        |
| `link`   | `linkSetMTU`          | Definir o MTU da interface                     |
| `link`   | `linkSetName`         | Renomear uma interface                         |
| `link`   | `linkSetMaster`       | Definir mestre da interface (bridge/bond)      |
| `link`   | `linkSetNoMaster`     | Remover interface do mestre                    |
| `link`   | `linkSetARPOn`        | Ativar ARP                                     |
| `link`   | `linkSetARPOff`       | Desativar ARP                                  |
| `link`   | `linkSetPromiscOn`    | Ativar modo promiscuo                          |
| `link`   | `linkSetPromiscOff`   | Desativar modo promiscuo                       |
| `link`   | `linkSetHardwareAddr` | Definir endereco MAC                           |
| `addr`   | `addrAdd`             | Adicionar um endereco IP a uma interface       |
| `addr`   | `addrReplace`         | Adicionar ou substituir um endereco IP         |
| `addr`   | `addrDel`             | Remover um endereco IP de uma interface        |
| `addr`   | `addrList`            | Listar enderecos IP de uma interface           |
| `route`  | `routeAdd`            | Adicionar uma rota                             |
| `route`  | `routeReplace`        | Adicionar ou substituir uma rota               |
| `route`  | `routeDel`            | Deletar uma rota                               |
| `route`  | `routeList`           | Listar rotas por familia de enderecos          |
| `route`  | `routeListFiltered`   | Listar rotas filtradas por interface           |
| `neigh`  | `neighAdd`            | Adicionar uma entrada de vizinho               |
| `neigh`  | `neighSet`            | Adicionar ou substituir uma entrada de vizinho |
| `neigh`  | `neighAppend`         | Anexar uma entrada de vizinho                  |
| `neigh`  | `neighDel`            | Deletar uma entrada de vizinho                 |
| `neigh`  | `neighList`           | Listar entradas de vizinhos                    |
| `types`  | `parseIPNet`          | Analisar uma string CIDR (ex. `"10.0.0.0/8"`) |
| `types`  | `parseIP`             | Analisar uma string de endereco IP             |
| `types`  | `newIPNet`            | Criar um IPNet com mascara de host (/32 ou /128)|
| `types`  | `computeBroadcast`    | Calcular o endereco de broadcast de uma sub-rede|

## Requisitos

- **Linux** -- Esta biblioteca utiliza a interface netlink do Linux e nao e portavel para outros sistemas operacionais.
- **Privilegios de root** -- A maioria das operacoes netlink que modificam a configuracao de rede requerem `CAP_NET_ADMIN` ou acesso root. Operacoes somente leitura (listar interfaces, enderecos, rotas, vizinhos) podem funcionar sem privilegios elevados.
- **Zig 0.15+** -- Compilada e testada com Zig 0.15. A versao minima especificada no `build.zig.zon` e 0.14.0, mas 0.15+ e recomendado.

## Testes

Execute o conjunto completo de testes usando o script fornecido:

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

Os testes de integracao modificam o estado da rede e requerem privilegios de root. O script automaticamente sera re-executado com `sudo` se necessario.

Voce tambem pode executar os testes diretamente com Zig:

```bash
zig build test
```

## Contribuicoes

Contribuicoes sao bem-vindas. Por favor, abra uma issue ou envie um pull request no GitHub.

Ao enviar alteracoes:

1. Certifique-se de que todos os testes passem (`./test.sh`)
2. Siga o estilo de codigo e as convencoes de nomenclatura existentes
3. Adicione testes para novas funcionalidades
4. Mantenha os commits focados e bem descritos

## Seguranca

Se voce descobrir uma vulnerabilidade de seguranca, por favor reporte de forma responsavel enviando um e-mail aos mantenedores em vez de abrir uma issue publica.

## Licenca

Licenciado sob a [Licenca Apache, Versao 2.0](LICENSE).

Copyright Zoptia. Todos os direitos reservados.
