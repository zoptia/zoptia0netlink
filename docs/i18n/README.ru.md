# zoptianetlink

**Библиотека netlink на чистом Zig для управления сетями в Linux -- [Zoptia](https://zoptia.com)**

[![Zig 0.15+](https://img.shields.io/badge/Zig-0.15%2B-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Linux only](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)]()
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)]()

[English](../../README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Português](README.pt-BR.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | [Русский]

---

`zoptianetlink` -- это библиотека netlink для Zig, которая предоставляет прямой, типобезопасный доступ к интерфейсу сокетов netlink в Linux для управления сетевыми интерфейсами, маршрутами, адресами и записями о соседях. Она служит программной альтернативой iproute2, позволяя настраивать все аспекты управления сетями в Linux -- создание и удаление каналов, назначение IP-адресов, управление таблицами маршрутизации и обновление записей соседей ARP/NDP -- все из нативного кода на Zig без зависимостей от C и без вызовов shell. Библиотека взаимодействует с ядром через протокол сокетов netlink (NETLINK_ROUTE), предоставляя тот же низкоуровневый контроль, что и инструменты `ip link`, `ip addr`, `ip route` и `ip neigh`, но с безопасностью на этапе компиляции и структурированной обработкой ошибок.

## Возможности

### Управление каналами (Сетевые интерфейсы)

- `linkAdd` -- Создание сетевых интерфейсов (bridge, veth, vlan, dummy, bond, wireguard и других)
- `linkDel` -- Удаление сетевых интерфейсов
- `linkList` -- Перечисление всех сетевых интерфейсов с полными деталями атрибутов
- `linkByName` / `linkByIndex` -- Поиск отдельного интерфейса по имени или индексу ядра
- `linkSetUp` / `linkSetDown` -- Включение или отключение интерфейсов
- `linkSetMTU` -- Изменение MTU интерфейса
- `linkSetName` -- Переименование интерфейса
- `linkSetMaster` / `linkSetNoMaster` -- Привязка или отвязка интерфейса от мастера (bridge, bond)
- `linkSetARPOn` / `linkSetARPOff` -- Включение или отключение ARP на интерфейсе
- `linkSetPromiscOn` / `linkSetPromiscOff` -- Включение или отключение режима promiscuous
- `linkSetHardwareAddr` -- Установка MAC-адреса интерфейса

### Управление адресами (IP-адреса)

- `addrAdd` -- Назначение IP-адреса интерфейсу
- `addrReplace` -- Добавление или замена IP-адреса на интерфейсе
- `addrDel` -- Удаление IP-адреса с интерфейса
- `addrList` -- Получение списка всех IP-адресов интерфейса с фильтрацией по семейству адресов

### Управление маршрутами (Таблица маршрутизации)

- `routeAdd` -- Добавление маршрута в таблицу маршрутизации
- `routeReplace` -- Добавление или замена маршрута
- `routeDel` -- Удаление маршрута из таблицы маршрутизации
- `routeList` -- Получение списка всех маршрутов для заданного семейства адресов
- `routeListFiltered` -- Получение списка маршрутов с фильтрацией по индексу интерфейса

### Управление соседями (ARP / NDP)

- `neighAdd` -- Добавление записи о соседе (ARP/NDP)
- `neighSet` -- Добавление или замена записи о соседе
- `neighAppend` -- Присоединение записи о соседе
- `neighDel` -- Удаление записи о соседе
- `neighList` -- Получение списка всех записей о соседях с фильтрацией по интерфейсу и семейству адресов

## Быстрый старт

### Добавление зависимости

Добавьте `zoptianetlink` в ваш `build.zig.zon`:

```zig
.dependencies = .{
    .zoptianetlink = .{
        .url = "https://github.com/zoptia/zoptianetlink/archive/refs/heads/main.tar.gz",
        // Replace with the actual hash after first `zig build`
        .hash = "...",
    },
},
```

Затем в вашем `build.zig`:

```zig
const netlink_dep = b.dependency("zoptianetlink", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("netlink", netlink_dep.module("netlink"));
```

### Минимальный пример

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

## Примеры использования

### Канал: Создание bridge и его активация

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

### Адрес: Назначение IP-адреса интерфейсу

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

### Маршрут: Добавление шлюза по умолчанию

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

### Сосед: Добавление статической записи ARP

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

## Поддерживаемые типы каналов

| Тип канала     | Значение enum  | Строка ядра       | Описание                               |
|----------------|----------------|--------------------|----------------------------------------|
| Device         | `.device`      | `device`           | Физическое сетевое устройство          |
| Dummy          | `.dummy`       | `dummy`            | Интерфейс dummy                        |
| IFB            | `.ifb`         | `ifb`              | Промежуточный функциональный блок      |
| Bridge         | `.bridge`      | `bridge`           | Мост Ethernet                          |
| VLAN           | `.vlan`        | `vlan`             | 802.1Q VLAN                            |
| Veth           | `.veth`        | `veth`             | Виртуальная пара Ethernet              |
| MACVLAN        | `.macvlan`     | `macvlan`          | Виртуальная LAN на основе MAC          |
| MACVTAP        | `.macvtap`     | `macvtap`          | TAP на основе MAC                      |
| TUN/TAP        | `.tuntap`      | `tuntap`           | Устройство TUN/TAP                     |
| VXLAN          | `.vxlan`       | `vxlan`            | Виртуальная расширяемая LAN            |
| IPVLAN         | `.ipvlan`      | `ipvlan`           | Виртуальная LAN на основе IP           |
| Bond           | `.bond`        | `bond`             | Bonding (агрегация каналов)            |
| Geneve         | `.geneve`      | `geneve`           | Обобщенная виртуализация сети          |
| GRE TAP        | `.gretap`      | `gretap`           | Туннель GRE L2                         |
| GRE Tunnel     | `.gretun`      | `gre`              | Туннель GRE L3                         |
| IP-in-IP       | `.iptun`       | `ipip`             | Туннель IPv4-в-IPv4                    |
| IP6TNL         | `.ip6tnl`      | `ip6tnl`           | Туннель IPv6                           |
| SIT            | `.sit`         | `sit`              | Туннель IPv6-в-IPv4                    |
| VTI            | `.vti`         | `vti`              | Виртуальный туннельный интерфейс       |
| VRF            | `.vrf`         | `vrf`              | Виртуальная маршрутизация и пересылка  |
| WireGuard      | `.wireguard`   | `wireguard`        | Безопасный туннель WireGuard           |

## Обзор API

| Модуль   | Функция               | Описание                                       |
|----------|-----------------------|------------------------------------------------|
| `link`   | `linkAdd`             | Создать новый сетевой интерфейс                |
| `link`   | `linkDel`             | Удалить сетевой интерфейс по индексу           |
| `link`   | `linkList`            | Получить список всех сетевых интерфейсов       |
| `link`   | `linkByName`          | Найти интерфейс по имени                       |
| `link`   | `linkByIndex`         | Найти интерфейс по индексу ядра                |
| `link`   | `linkSetUp`           | Включить интерфейс                             |
| `link`   | `linkSetDown`         | Отключить интерфейс                            |
| `link`   | `linkSetMTU`          | Установить MTU интерфейса                      |
| `link`   | `linkSetName`         | Переименовать интерфейс                        |
| `link`   | `linkSetMaster`       | Назначить мастер интерфейса (bridge/bond)       |
| `link`   | `linkSetNoMaster`     | Отвязать интерфейс от мастера                  |
| `link`   | `linkSetARPOn`        | Включить ARP                                   |
| `link`   | `linkSetARPOff`       | Отключить ARP                                  |
| `link`   | `linkSetPromiscOn`    | Включить режим promiscuous                     |
| `link`   | `linkSetPromiscOff`   | Отключить режим promiscuous                    |
| `link`   | `linkSetHardwareAddr` | Установить MAC-адрес                           |
| `addr`   | `addrAdd`             | Добавить IP-адрес на интерфейс                 |
| `addr`   | `addrReplace`         | Добавить или заменить IP-адрес                 |
| `addr`   | `addrDel`             | Удалить IP-адрес с интерфейса                  |
| `addr`   | `addrList`            | Получить список IP-адресов интерфейса          |
| `route`  | `routeAdd`            | Добавить маршрут                               |
| `route`  | `routeReplace`        | Добавить или заменить маршрут                  |
| `route`  | `routeDel`            | Удалить маршрут                                |
| `route`  | `routeList`           | Получить список маршрутов по семейству адресов  |
| `route`  | `routeListFiltered`   | Получить список маршрутов с фильтром по интерфейсу |
| `neigh`  | `neighAdd`            | Добавить запись о соседе                       |
| `neigh`  | `neighSet`            | Добавить или заменить запись о соседе           |
| `neigh`  | `neighAppend`         | Присоединить запись о соседе                   |
| `neigh`  | `neighDel`            | Удалить запись о соседе                        |
| `neigh`  | `neighList`           | Получить список записей о соседях              |
| `types`  | `parseIPNet`          | Разобрать строку CIDR (напр. `"10.0.0.0/8"`)  |
| `types`  | `parseIP`             | Разобрать строку IP-адреса                     |
| `types`  | `newIPNet`            | Создать IPNet с маской хоста (/32 или /128)    |
| `types`  | `computeBroadcast`    | Вычислить широковещательный адрес подсети       |

## Требования

- **Linux** -- Эта библиотека использует интерфейс netlink Linux и не является переносимой на другие операционные системы.
- **Привилегии root** -- Большинство операций netlink, изменяющих конфигурацию сети, требуют `CAP_NET_ADMIN` или доступ root. Операции только для чтения (получение списка интерфейсов, адресов, маршрутов, соседей) могут работать без повышенных привилегий.
- **Zig 0.15+** -- Собрана и протестирована с Zig 0.15. Минимальная версия, указанная в `build.zig.zon`, составляет 0.14.0, но рекомендуется 0.15+.

## Тестирование

Запустите полный набор тестов с помощью предоставленного скрипта:

```bash
./test.sh            # Run all tests (unit + integration)
./test.sh unit        # Run unit tests only
./test.sh integration # Run integration tests only (requires root)
```

Интеграционные тесты изменяют состояние сети и требуют привилегий root. Скрипт автоматически перезапустится с `sudo` при необходимости.

Вы также можете запустить тесты напрямую через Zig:

```bash
zig build test
```

## Участие в разработке

Мы приветствуем вклад в проект. Пожалуйста, откройте issue или отправьте pull request на GitHub.

При отправке изменений:

1. Убедитесь, что все тесты проходят (`./test.sh`)
2. Следуйте существующему стилю кода и соглашениям об именовании
3. Добавляйте тесты для новой функциональности
4. Делайте коммиты целенаправленными и хорошо описанными

## Безопасность

Если вы обнаружите уязвимость безопасности, пожалуйста, сообщите о ней ответственно, отправив электронное письмо разработчикам, а не открывая публичный issue.

## Лицензия

Лицензировано по [Apache License, Version 2.0](LICENSE).

Copyright Zoptia. Все права защищены.
