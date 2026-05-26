const std = @import("std");
const nl = @import("nl.zig");

// LinkOperState represents the RFC2863 state of an interface.
pub const LinkOperState = enum(u8) {
    unknown = 0,
    not_present = 1,
    down = 2,
    lower_layer_down = 3,
    testing = 4,
    dormant = 5,
    up = 6,

    pub fn toString(self: LinkOperState) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .not_present => "not-present",
            .down => "down",
            .lower_layer_down => "lower-layer-down",
            .testing => "testing",
            .dormant => "dormant",
            .up => "up",
        };
    }
};

// Scope is an enum representing a route scope.
pub const Scope = enum(u8) {
    universe = nl.RT_SCOPE_UNIVERSE,
    site = nl.RT_SCOPE_SITE,
    link = nl.RT_SCOPE_LINK,
    host = nl.RT_SCOPE_HOST,
    nowhere = nl.RT_SCOPE_NOWHERE,

    pub fn toString(self: Scope) []const u8 {
        return switch (self) {
            .universe => "universe",
            .site => "site",
            .link => "link",
            .host => "host",
            .nowhere => "nowhere",
        };
    }
};

// RouteProtocol describes what originated the route.
pub const RouteProtocol = enum(u8) {
    unspec = nl.RTPROT_UNSPEC,
    redirect = nl.RTPROT_REDIRECT,
    kernel = nl.RTPROT_KERNEL,
    boot = nl.RTPROT_BOOT,
    static_ = nl.RTPROT_STATIC,
    _,
};

// LinkStatistics64 matches the kernel's rtnl_link_stats64.
pub const LinkStatistics64 = extern struct {
    rx_packets: u64 = 0,
    tx_packets: u64 = 0,
    rx_bytes: u64 = 0,
    tx_bytes: u64 = 0,
    rx_errors: u64 = 0,
    tx_errors: u64 = 0,
    rx_dropped: u64 = 0,
    tx_dropped: u64 = 0,
    multicast: u64 = 0,
    collisions: u64 = 0,
    rx_length_errors: u64 = 0,
    rx_over_errors: u64 = 0,
    rx_crc_errors: u64 = 0,
    rx_frame_errors: u64 = 0,
    rx_fifo_errors: u64 = 0,
    rx_missed_errors: u64 = 0,
    tx_aborted_errors: u64 = 0,
    tx_carrier_errors: u64 = 0,
    tx_fifo_errors: u64 = 0,
    tx_heartbeat_errors: u64 = 0,
    tx_window_errors: u64 = 0,
    rx_compressed: u64 = 0,
    tx_compressed: u64 = 0,
};

pub const LinkStatistics = LinkStatistics64;

// LinkAttrs represents data shared by most link types.
pub const LinkAttrs = struct {
    index: i32 = 0,
    mtu: u32 = 0,
    tx_qlen: i32 = -1,
    name: [16]u8 = [_]u8{0} ** 16,
    name_len: u8 = 0,
    hardware_addr: ?[6]u8 = null,
    flags: u32 = 0,
    raw_flags: u32 = 0,
    parent_index: i32 = 0,
    master_index: i32 = 0,
    oper_state: LinkOperState = .unknown,
    statistics: ?LinkStatistics = null,
    group: u32 = 0,
    num_tx_queues: u32 = 0,
    num_rx_queues: u32 = 0,
    gso_max_segs: u32 = 0,
    gso_max_size: u32 = 0,
    gro_max_size: u32 = 0,
    net_ns_id: i32 = -1,
    promisc: u32 = 0,
    allmulti: u32 = 0,
    alias: [256]u8 = [_]u8{0} ** 256,
    alias_len: u8 = 0,
    link_type: LinkType = .device,
    encap_type: [32]u8 = [_]u8{0} ** 32,
    encap_type_len: u8 = 0,
    // Generic IFLA_HEADROOM / IFLA_TAILROOM (query-only).
    headroom: u16 = 0,
    tailroom: u16 = 0,

    // VLAN-specific (used when link_type == .vlan).
    vlan_id: u16 = 0,
    vlan_proto: u16 = 0,
    vlan_flags: u32 = 0,
    vlan_flags_mask: u32 = 0,

    // GRE-specific (used for gretap/gretun).
    gre_ignore_df: ?bool = null,

    // VXLAN-specific.
    vxlan_id: u32 = 0,
    vxlan_vni_filter: ?bool = null,

    pub fn getName(self: *const LinkAttrs) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn setName(self: *LinkAttrs, name: []const u8) void {
        const len = @min(name.len, self.name.len - 1);
        @memcpy(self.name[0..len], name[0..len]);
        self.name[len] = 0;
        self.name_len = @intCast(len);
    }

    pub fn getAlias(self: *const LinkAttrs) []const u8 {
        return self.alias[0..self.alias_len];
    }
};

// LinkType identifies the type of a link.
pub const LinkType = enum {
    device,
    dummy,
    ifb,
    bridge,
    vlan,
    veth,
    macvlan,
    macvtap,
    tuntap,
    vxlan,
    ipvlan,
    bond,
    geneve,
    gretap,
    gretun,
    iptun,
    ip6tnl,
    sit,
    vti,
    vrf,
    wireguard,
    generic,

    pub fn toString(self: LinkType) []const u8 {
        return switch (self) {
            .device => "device",
            .dummy => "dummy",
            .ifb => "ifb",
            .bridge => "bridge",
            .vlan => "vlan",
            .veth => "veth",
            .macvlan => "macvlan",
            .macvtap => "macvtap",
            .tuntap => "tuntap",
            .vxlan => "vxlan",
            .ipvlan => "ipvlan",
            .bond => "bond",
            .geneve => "geneve",
            .gretap => "gretap",
            .gretun => "gre",
            .iptun => "ipip",
            .ip6tnl => "ip6tnl",
            .sit => "sit",
            .vti => "vti",
            .vrf => "vrf",
            .wireguard => "wireguard",
            .generic => "generic",
        };
    }

    pub fn fromString(s: []const u8) LinkType {
        const map = std.StaticStringMap(LinkType).initComptime(.{
            .{ "device", .device },
            .{ "dummy", .dummy },
            .{ "ifb", .ifb },
            .{ "bridge", .bridge },
            .{ "vlan", .vlan },
            .{ "veth", .veth },
            .{ "macvlan", .macvlan },
            .{ "macvtap", .macvtap },
            .{ "tuntap", .tuntap },
            .{ "vxlan", .vxlan },
            .{ "ipvlan", .ipvlan },
            .{ "bond", .bond },
            .{ "geneve", .geneve },
            .{ "gretap", .gretap },
            .{ "gre", .gretun },
            .{ "ipip", .iptun },
            .{ "ip6tnl", .ip6tnl },
            .{ "sit", .sit },
            .{ "vti", .vti },
            .{ "vrf", .vrf },
            .{ "wireguard", .wireguard },
        });
        return map.get(s) orelse .generic;
    }
};

// Addr represents an IP address from netlink.
pub const Addr = struct {
    ip: nl.Address,
    prefix_len: u8,
    label: [16]u8 = [_]u8{0} ** 16,
    label_len: u8 = 0,
    flags: u32 = 0,
    scope: u8 = 0,
    peer: ?IPNet = null,
    broadcast: ?nl.Address = null,
    preferred_lft: u32 = 0,
    valid_lft: u32 = 0,
    link_index: i32 = 0,
    protocol: u8 = 0,

    pub fn getLabel(self: *const Addr) []const u8 {
        return self.label[0..self.label_len];
    }

    pub fn setLabel(self: *Addr, lbl: []const u8) void {
        const len = @min(lbl.len, self.label.len - 1);
        @memcpy(self.label[0..len], lbl[0..len]);
        self.label[len] = 0;
        self.label_len = @intCast(len);
    }

    pub fn eql(self: *const Addr, other: *const Addr) bool {
        return self.ip.eql(other.ip) and self.prefix_len == other.prefix_len;
    }

    pub fn family(self: *const Addr) u8 {
        return nl.getIPFamily(self.ip);
    }

    pub fn ipNet(self: *const Addr) IPNet {
        return .{
            .ip = self.ip,
            .prefix_len = self.prefix_len,
        };
    }
};

pub const IPNet = struct {
    ip: nl.Address,
    prefix_len: u8,

    pub fn eql(self: *const IPNet, other: *const IPNet) bool {
        return self.ip.eql(other.ip) and self.prefix_len == other.prefix_len;
    }

    pub fn contains(self: *const IPNet, addr: nl.Address) bool {
        const self_bytes = self.ip.toBytes();
        const addr_bytes = addr.toBytes();
        if (self_bytes.len != addr_bytes.len) return false;

        const full_bytes = self.prefix_len / 8;
        const rem_bits = self.prefix_len % 8;

        var i: usize = 0;
        while (i < full_bytes) : (i += 1) {
            if (self_bytes[i] != addr_bytes[i]) return false;
        }
        if (rem_bits > 0 and i < self_bytes.len) {
            const mask: u8 = @as(u8, 0xFF) << @intCast(8 - rem_bits);
            if ((self_bytes[i] & mask) != (addr_bytes[i] & mask)) return false;
        }
        return true;
    }
};

// Ip6tnlEncap describes an IPv6 LWT tunnel encapsulation attached to a route.
// Wire format: RTA_ENCAP_TYPE = LWTUNNEL_ENCAP_IP6, RTA_ENCAP = nested
// LWTUNNEL_IP6_* attributes. ID and FLAGS are transmitted in network byte
// order; matches the upstream IP6tnlEncap fix.
pub const Ip6tnlEncap = struct {
    id: u64 = 0,
    dst: ?[16]u8 = null,
    src: ?[16]u8 = null,
    hoplimit: u8 = 0,
    tc: u8 = 0,
    flags: u16 = 0,
};

// Route represents a netlink route.
pub const Route = struct {
    link_index: i32 = 0,
    scope: Scope = .universe,
    dst: ?IPNet = null,
    src: ?nl.Address = null,
    gw: ?nl.Address = null,
    protocol: RouteProtocol = .boot,
    priority: u32 = 0,
    family: u8 = 0,
    table: u32 = nl.RT_TABLE_MAIN,
    type_: u8 = nl.RTN_UNICAST,
    tos: u8 = 0,
    flags: u32 = 0,
    mtu: u32 = 0,
    // RTA_EXPIRES: lifetime of the route in seconds; null = not set.
    expires: ?u32 = null,
    // LWT IP6 tunnel encapsulation; null = not set.
    encap_ip6: ?Ip6tnlEncap = null,

    pub fn eql(self: *const Route, other: *const Route) bool {
        var dst_eq = false;
        if (self.dst) |sd| {
            if (other.dst) |od| {
                dst_eq = sd.eql(&od);
            }
        } else {
            dst_eq = other.dst == null;
        }

        var gw_eq = false;
        if (self.gw) |sg| {
            if (other.gw) |og| {
                gw_eq = sg.eql(og);
            }
        } else {
            gw_eq = other.gw == null;
        }

        return self.link_index == other.link_index and
            dst_eq and gw_eq and
            self.scope == other.scope and
            @intFromEnum(self.protocol) == @intFromEnum(other.protocol) and
            self.table == other.table;
    }
};

// Neigh represents a link layer neighbor from netlink.
pub const Neigh = struct {
    link_index: i32 = 0,
    family: u8 = 0,
    state: u16 = 0,
    type_: u8 = 0,
    flags: u8 = 0,
    flags_ext: u32 = 0,
    ip: nl.Address,
    hardware_addr: ?[6]u8 = null,
    vlan: u16 = 0,
    vni: u32 = 0,
    master_index: i32 = 0,

    pub fn eql(self: *const Neigh, other: *const Neigh) bool {
        return self.ip.eql(other.ip) and
            self.link_index == other.link_index and
            self.state == other.state;
    }
};

// parseIPNet parses a CIDR string into an IPNet.
pub fn parseIPNet(cidr: []const u8) !IPNet {
    var slash_pos: ?usize = null;
    for (cidr, 0..) |c, i| {
        if (c == '/') {
            slash_pos = i;
            break;
        }
    }
    const sp = slash_pos orelse return error.InvalidCIDR;
    const ip_str = cidr[0..sp];
    const prefix_str = cidr[sp + 1 ..];
    const prefix_len = std.fmt.parseInt(u8, prefix_str, 10) catch return error.InvalidCIDR;
    const ip = try parseIP(ip_str);
    return .{ .ip = ip, .prefix_len = prefix_len };
}

pub fn parseIP(ip_str: []const u8) !nl.Address {
    // check if IPv6 (contains ':')
    for (ip_str) |c| {
        if (c == ':') return parseIPv6(ip_str);
    }
    return parseIPv4(ip_str);
}

fn parseIPv4(s: []const u8) !nl.Address {
    var result: [4]u8 = undefined;
    var octet: u8 = 0;
    var octet_idx: u8 = 0;
    var has_digit = false;

    for (s) |c| {
        if (c == '.') {
            if (!has_digit or octet_idx >= 3) return error.InvalidIP;
            result[octet_idx] = octet;
            octet_idx += 1;
            octet = 0;
            has_digit = false;
        } else if (c >= '0' and c <= '9') {
            const new_val = @as(u16, octet) * 10 + (c - '0');
            if (new_val > 255) return error.InvalidIP;
            octet = @intCast(new_val);
            has_digit = true;
        } else {
            return error.InvalidIP;
        }
    }
    if (!has_digit or octet_idx != 3) return error.InvalidIP;
    result[3] = octet;
    return .{ .v4 = result };
}

fn parseIPv6(s: []const u8) !nl.Address {
    var result: [16]u8 = [_]u8{0} ** 16;

    // simple IPv6 parser: handle "::" expansion
    if (s.len == 0) return error.InvalidIP;

    var parts: [8]u16 = [_]u16{0} ** 8;
    var part_count: u8 = 0;
    var double_colon_pos: ?u8 = null;
    var current: u16 = 0;
    var has_digit_local = false;
    var i: usize = 0;

    while (i < s.len) {
        if (s[i] == ':') {
            if (i + 1 < s.len and s[i + 1] == ':') {
                if (double_colon_pos != null) return error.InvalidIP;
                if (has_digit_local) {
                    if (part_count >= 8) return error.InvalidIP;
                    parts[part_count] = current;
                    part_count += 1;
                }
                double_colon_pos = part_count;
                current = 0;
                has_digit_local = false;
                i += 2;
                continue;
            }
            if (has_digit_local) {
                if (part_count >= 8) return error.InvalidIP;
                parts[part_count] = current;
                part_count += 1;
            }
            current = 0;
            has_digit_local = false;
            i += 1;
            continue;
        }

        const digit = std.fmt.charToDigit(s[i], 16) catch return error.InvalidIP;
        current = current * 16 + digit;
        has_digit_local = true;
        i += 1;
    }
    if (has_digit_local) {
        if (part_count >= 8) return error.InvalidIP;
        parts[part_count] = current;
        part_count += 1;
    }

    if (double_colon_pos) |pos| {
        const tail_len = part_count - pos;
        const shift = 8 - part_count;
        // move tail parts to the end
        var j: u8 = 0;
        while (j < tail_len) : (j += 1) {
            parts[7 - j] = parts[part_count - 1 - j];
        }
        // zero fill the gap
        j = pos;
        while (j < pos + shift) : (j += 1) {
            parts[j] = 0;
        }
    } else if (part_count != 8) {
        return error.InvalidIP;
    }

    for (0..8) |idx| {
        result[idx * 2] = @intCast(parts[idx] >> 8);
        result[idx * 2 + 1] = @intCast(parts[idx] & 0xFF);
    }

    return .{ .v6 = result };
}

// newIPNet creates an IPNet with a /32 or /128 mask.
pub fn newIPNet(ip: nl.Address) IPNet {
    return .{
        .ip = ip,
        .prefix_len = switch (ip) {
            .v4 => 32,
            .v6 => 128,
        },
    };
}

pub fn computeBroadcast(ip: [4]u8, prefix_len: u8) [4]u8 {
    var result: [4]u8 = undefined;
    for (0..4) |i| {
        const host_bits = if (i * 8 + 8 <= prefix_len) 0 else if (i * 8 >= prefix_len) 8 else 8 - (prefix_len - @as(u8, @intCast(i * 8)));
        const mask: u8 = if (host_bits == 8) 0xFF else (@as(u8, 1) << @intCast(host_bits)) - 1;
        result[i] = ip[i] | mask;
    }
    return result;
}
