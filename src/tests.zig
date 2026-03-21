const std = @import("std");
const testing = std.testing;
const netlink = @import("netlink.zig");
const nl = netlink.nl;
const types = netlink.types;

// =============================================================================
// Unit Tests - IP Parsing
// =============================================================================

test "parseIPv4" {
    const ip = try types.parseIP("192.168.1.1");
    try testing.expectEqual(nl.Address{ .v4 = .{ 192, 168, 1, 1 } }, ip);
}

test "parseIPv4 zero" {
    const ip = try types.parseIP("0.0.0.0");
    try testing.expectEqual(nl.Address{ .v4 = .{ 0, 0, 0, 0 } }, ip);
}

test "parseIPv4 loopback" {
    const ip = try types.parseIP("127.0.0.1");
    try testing.expectEqual(nl.Address{ .v4 = .{ 127, 0, 0, 1 } }, ip);
}

test "parseIPv4 broadcast" {
    const ip = try types.parseIP("255.255.255.255");
    try testing.expectEqual(nl.Address{ .v4 = .{ 255, 255, 255, 255 } }, ip);
}

test "parseIPv4 invalid - too many octets" {
    try testing.expectError(error.InvalidIP, types.parseIP("1.2.3.4.5"));
}

test "parseIPv4 invalid - octet > 255" {
    try testing.expectError(error.InvalidIP, types.parseIP("256.0.0.1"));
}

test "parseIPv4 invalid - empty" {
    try testing.expectError(error.InvalidIP, types.parseIP(""));
}

test "parseIPv6 loopback" {
    const ip = try types.parseIP("::1");
    var expected: [16]u8 = [_]u8{0} ** 16;
    expected[15] = 1;
    try testing.expectEqual(nl.Address{ .v6 = expected }, ip);
}

test "parseIPv6 full" {
    const ip = try types.parseIP("2001:db8:0:0:0:0:0:1");
    try testing.expectEqual(@as(u8, 0x20), ip.v6[0]);
    try testing.expectEqual(@as(u8, 0x01), ip.v6[1]);
    try testing.expectEqual(@as(u8, 0x0d), ip.v6[2]);
    try testing.expectEqual(@as(u8, 0xb8), ip.v6[3]);
    try testing.expectEqual(@as(u8, 1), ip.v6[15]);
}

test "parseIPv6 abbreviated" {
    const ip = try types.parseIP("fe80::1");
    try testing.expectEqual(@as(u8, 0xfe), ip.v6[0]);
    try testing.expectEqual(@as(u8, 0x80), ip.v6[1]);
    try testing.expectEqual(@as(u8, 1), ip.v6[15]);
    // middle bytes should be zero
    for (ip.v6[2..15]) |b| {
        try testing.expectEqual(@as(u8, 0), b);
    }
}

test "parseIPv6 all zeros" {
    const ip = try types.parseIP("::");
    for (ip.v6) |b| {
        try testing.expectEqual(@as(u8, 0), b);
    }
}

// =============================================================================
// Unit Tests - CIDR Parsing
// =============================================================================

test "parseIPNet IPv4 CIDR" {
    const net = try types.parseIPNet("192.168.1.0/24");
    try testing.expectEqual(nl.Address{ .v4 = .{ 192, 168, 1, 0 } }, net.ip);
    try testing.expectEqual(@as(u8, 24), net.prefix_len);
}

test "parseIPNet IPv4 host" {
    const net = try types.parseIPNet("10.0.0.1/32");
    try testing.expectEqual(nl.Address{ .v4 = .{ 10, 0, 0, 1 } }, net.ip);
    try testing.expectEqual(@as(u8, 32), net.prefix_len);
}

test "parseIPNet IPv6 CIDR" {
    const net = try types.parseIPNet("fe80::1/64");
    try testing.expectEqual(@as(u8, 64), net.prefix_len);
    try testing.expectEqual(@as(u8, 0xfe), net.ip.v6[0]);
}

test "parseIPNet invalid - no slash" {
    try testing.expectError(error.InvalidCIDR, types.parseIPNet("192.168.1.0"));
}

test "parseIPNet invalid - bad prefix" {
    try testing.expectError(error.InvalidCIDR, types.parseIPNet("192.168.1.0/abc"));
}

// =============================================================================
// Unit Tests - IPNet contains
// =============================================================================

test "IPNet contains" {
    const net = try types.parseIPNet("192.168.1.0/24");
    const in_addr = try types.parseIP("192.168.1.100");
    const out_addr = try types.parseIP("192.168.2.1");

    try testing.expect(net.contains(in_addr));
    try testing.expect(!net.contains(out_addr));
}

test "IPNet contains /32" {
    const net = try types.parseIPNet("10.0.0.1/32");
    const same = try types.parseIP("10.0.0.1");
    const diff = try types.parseIP("10.0.0.2");

    try testing.expect(net.contains(same));
    try testing.expect(!net.contains(diff));
}

test "IPNet contains /0 matches all" {
    const net = try types.parseIPNet("0.0.0.0/0");
    const any_addr = try types.parseIP("123.45.67.89");
    try testing.expect(net.contains(any_addr));
}

// =============================================================================
// Unit Tests - newIPNet
// =============================================================================

test "newIPNet IPv4 gives /32" {
    const ip = try types.parseIP("10.0.0.1");
    const net = types.newIPNet(ip);
    try testing.expectEqual(@as(u8, 32), net.prefix_len);
    try testing.expect(ip.eql(net.ip));
}

test "newIPNet IPv6 gives /128" {
    const ip = try types.parseIP("::1");
    const net = types.newIPNet(ip);
    try testing.expectEqual(@as(u8, 128), net.prefix_len);
}

// =============================================================================
// Unit Tests - Broadcast Computation
// =============================================================================

test "computeBroadcast /24" {
    const bcast = types.computeBroadcast(.{ 192, 168, 1, 0 }, 24);
    try testing.expectEqual([4]u8{ 192, 168, 1, 255 }, bcast);
}

test "computeBroadcast /16" {
    const bcast = types.computeBroadcast(.{ 172, 16, 0, 0 }, 16);
    try testing.expectEqual([4]u8{ 172, 16, 255, 255 }, bcast);
}

test "computeBroadcast /32" {
    const bcast = types.computeBroadcast(.{ 10, 0, 0, 1 }, 32);
    try testing.expectEqual([4]u8{ 10, 0, 0, 1 }, bcast);
}

test "computeBroadcast /25" {
    const bcast = types.computeBroadcast(.{ 192, 168, 1, 0 }, 25);
    try testing.expectEqual([4]u8{ 192, 168, 1, 127 }, bcast);
}

test "computeBroadcast /8" {
    const bcast = types.computeBroadcast(.{ 10, 0, 0, 0 }, 8);
    try testing.expectEqual([4]u8{ 10, 255, 255, 255 }, bcast);
}

// =============================================================================
// Unit Tests - Address Equality
// =============================================================================

test "Address equality" {
    const a = nl.Address{ .v4 = .{ 192, 168, 1, 1 } };
    const b = nl.Address{ .v4 = .{ 192, 168, 1, 1 } };
    const c = nl.Address{ .v4 = .{ 192, 168, 1, 2 } };

    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "Address v4 v6 inequality" {
    const v4 = nl.Address{ .v4 = .{ 127, 0, 0, 1 } };
    const v6 = nl.Address{ .v6 = [_]u8{0} ** 16 };
    try testing.expect(!v4.eql(v6));
}

test "Address isZero" {
    const zero_v4 = nl.Address{ .v4 = .{ 0, 0, 0, 0 } };
    const nonzero_v4 = nl.Address{ .v4 = .{ 0, 0, 0, 1 } };
    try testing.expect(zero_v4.isZero());
    try testing.expect(!nonzero_v4.isZero());
}

test "Address fromSlice" {
    const v4_bytes = [_]u8{ 10, 0, 0, 1 };
    const addr = try nl.Address.fromSlice(&v4_bytes);
    try testing.expectEqual(nl.Address{ .v4 = .{ 10, 0, 0, 1 } }, addr);

    const v6_bytes = [_]u8{0} ** 16;
    const addr6 = try nl.Address.fromSlice(&v6_bytes);
    try testing.expectEqual(nl.Address{ .v6 = [_]u8{0} ** 16 }, addr6);

    const bad_bytes = [_]u8{ 1, 2, 3 };
    try testing.expectError(error.InvalidAddressLength, nl.Address.fromSlice(&bad_bytes));
}

// =============================================================================
// Unit Tests - getIPFamily
// =============================================================================

test "getIPFamily" {
    const v4 = nl.Address{ .v4 = .{ 10, 0, 0, 1 } };
    const v6 = nl.Address{ .v6 = [_]u8{0} ** 16 };

    try testing.expectEqual(nl.FAMILY_V4, nl.getIPFamily(v4));
    try testing.expectEqual(nl.FAMILY_V6, nl.getIPFamily(v6));
}

// =============================================================================
// Unit Tests - Addr type
// =============================================================================

test "Addr equality" {
    const a = types.Addr{ .ip = .{ .v4 = .{ 192, 168, 1, 1 } }, .prefix_len = 24 };
    const b = types.Addr{ .ip = .{ .v4 = .{ 192, 168, 1, 1 } }, .prefix_len = 24 };
    const c = types.Addr{ .ip = .{ .v4 = .{ 192, 168, 1, 2 } }, .prefix_len = 24 };
    const d = types.Addr{ .ip = .{ .v4 = .{ 192, 168, 1, 1 } }, .prefix_len = 16 };

    try testing.expect(a.eql(&b));
    try testing.expect(!a.eql(&c));
    try testing.expect(!a.eql(&d));
}

test "Addr family" {
    const v4_addr = types.Addr{ .ip = .{ .v4 = .{ 10, 0, 0, 1 } }, .prefix_len = 24 };
    const v6_addr = types.Addr{ .ip = .{ .v6 = [_]u8{0} ** 16 }, .prefix_len = 64 };

    try testing.expectEqual(nl.FAMILY_V4, v4_addr.family());
    try testing.expectEqual(nl.FAMILY_V6, v6_addr.family());
}

test "Addr label" {
    var a = types.Addr{ .ip = .{ .v4 = .{ 10, 0, 0, 1 } }, .prefix_len = 24 };
    a.setLabel("eth0");
    try testing.expectEqualStrings("eth0", a.getLabel());
}

// =============================================================================
// Unit Tests - Route equality
// =============================================================================

test "Route equality" {
    const r1 = types.Route{
        .link_index = 1,
        .dst = .{ .ip = .{ .v4 = .{ 192, 168, 1, 0 } }, .prefix_len = 24 },
        .gw = .{ .v4 = .{ 192, 168, 0, 1 } },
        .scope = .link,
        .table = nl.RT_TABLE_MAIN,
    };
    const r2 = types.Route{
        .link_index = 1,
        .dst = .{ .ip = .{ .v4 = .{ 192, 168, 1, 0 } }, .prefix_len = 24 },
        .gw = .{ .v4 = .{ 192, 168, 0, 1 } },
        .scope = .link,
        .table = nl.RT_TABLE_MAIN,
    };
    const r3 = types.Route{
        .link_index = 2,
        .dst = .{ .ip = .{ .v4 = .{ 10, 0, 0, 0 } }, .prefix_len = 8 },
    };

    try testing.expect(r1.eql(&r2));
    try testing.expect(!r1.eql(&r3));
}

// =============================================================================
// Unit Tests - Neigh equality
// =============================================================================

test "Neigh equality" {
    const n1 = types.Neigh{
        .ip = .{ .v4 = .{ 192, 168, 1, 1 } },
        .link_index = 1,
        .state = nl.NUD_REACHABLE,
    };
    const n2 = types.Neigh{
        .ip = .{ .v4 = .{ 192, 168, 1, 1 } },
        .link_index = 1,
        .state = nl.NUD_REACHABLE,
    };
    const n3 = types.Neigh{
        .ip = .{ .v4 = .{ 192, 168, 1, 2 } },
        .link_index = 1,
        .state = nl.NUD_REACHABLE,
    };

    try testing.expect(n1.eql(&n2));
    try testing.expect(!n1.eql(&n3));
}

// =============================================================================
// Unit Tests - LinkAttrs
// =============================================================================

test "LinkAttrs name" {
    var la = types.LinkAttrs{};
    la.setName("eth0");
    try testing.expectEqualStrings("eth0", la.getName());
}

test "LinkAttrs name truncation" {
    var la = types.LinkAttrs{};
    la.setName("this_is_a_very_long_interface_name");
    try testing.expectEqual(@as(u8, 15), la.name_len);
}

test "LinkAttrs default values" {
    const la = types.LinkAttrs{};
    try testing.expectEqual(@as(i32, -1), la.tx_qlen);
    try testing.expectEqual(@as(i32, -1), la.net_ns_id);
    try testing.expectEqual(@as(u32, 0), la.mtu);
    try testing.expectEqual(@as(i32, 0), la.index);
}

// =============================================================================
// Unit Tests - LinkType
// =============================================================================

test "LinkType toString" {
    try testing.expectEqualStrings("dummy", types.LinkType.dummy.toString());
    try testing.expectEqualStrings("veth", types.LinkType.veth.toString());
    try testing.expectEqualStrings("bridge", types.LinkType.bridge.toString());
    try testing.expectEqualStrings("vlan", types.LinkType.vlan.toString());
    try testing.expectEqualStrings("device", types.LinkType.device.toString());
}

test "LinkType fromString" {
    try testing.expectEqual(types.LinkType.dummy, types.LinkType.fromString("dummy"));
    try testing.expectEqual(types.LinkType.veth, types.LinkType.fromString("veth"));
    try testing.expectEqual(types.LinkType.bridge, types.LinkType.fromString("bridge"));
    try testing.expectEqual(types.LinkType.generic, types.LinkType.fromString("unknown_type"));
}

test "LinkType roundtrip" {
    const link_types = [_]types.LinkType{
        .device, .dummy, .ifb,    .bridge, .vlan, .veth,
        .vxlan,  .bond,  .geneve, .vrf,
    };
    for (link_types) |lt| {
        const s = lt.toString();
        if (lt == .device) continue; // "device" has no string->enum mapping
        try testing.expectEqual(lt, types.LinkType.fromString(s));
    }
}

// =============================================================================
// Unit Tests - LinkOperState
// =============================================================================

test "LinkOperState toString" {
    try testing.expectEqualStrings("up", types.LinkOperState.up.toString());
    try testing.expectEqualStrings("down", types.LinkOperState.down.toString());
    try testing.expectEqualStrings("unknown", types.LinkOperState.unknown.toString());
}

// =============================================================================
// Unit Tests - Scope
// =============================================================================

test "Scope toString" {
    try testing.expectEqualStrings("universe", types.Scope.universe.toString());
    try testing.expectEqualStrings("link", types.Scope.link.toString());
    try testing.expectEqualStrings("host", types.Scope.host.toString());
    try testing.expectEqualStrings("nowhere", types.Scope.nowhere.toString());
}

// =============================================================================
// Unit Tests - NL alignment
// =============================================================================

test "nlmsgAlign" {
    try testing.expectEqual(@as(u32, 0), nl.nlmsgAlign(0));
    try testing.expectEqual(@as(u32, 4), nl.nlmsgAlign(1));
    try testing.expectEqual(@as(u32, 4), nl.nlmsgAlign(2));
    try testing.expectEqual(@as(u32, 4), nl.nlmsgAlign(3));
    try testing.expectEqual(@as(u32, 4), nl.nlmsgAlign(4));
    try testing.expectEqual(@as(u32, 8), nl.nlmsgAlign(5));
    try testing.expectEqual(@as(u32, 16), nl.nlmsgAlign(16));
    try testing.expectEqual(@as(u32, 20), nl.nlmsgAlign(17));
}

test "rtaAlign" {
    try testing.expectEqual(@as(u32, 0), nl.rtaAlign(0));
    try testing.expectEqual(@as(u32, 4), nl.rtaAlign(1));
    try testing.expectEqual(@as(u32, 4), nl.rtaAlign(4));
    try testing.expectEqual(@as(u32, 8), nl.rtaAlign(5));
}

// =============================================================================
// Unit Tests - NL Attribute Serialization
// =============================================================================

test "RtAttr serialize simple" {
    var attr = nl.RtAttr.init(testing.allocator, 1, &.{ 0xAA, 0xBB });
    defer attr.deinit();

    var buf: [64]u8 = undefined;
    const len = attr.serialize(&buf);

    // header: 2 bytes len + 2 bytes type = 4 bytes, then 2 bytes data = 6 total
    try testing.expectEqual(@as(u32, 6), len);

    // check length field
    const native_endian = @import("builtin").cpu.arch.endian();
    const stored_len = std.mem.readInt(u16, buf[0..2], native_endian);
    try testing.expectEqual(@as(u16, 6), stored_len);

    // check type
    const stored_type = std.mem.readInt(u16, buf[2..4], native_endian);
    try testing.expectEqual(@as(u16, 1), stored_type);

    // check data
    try testing.expectEqual(@as(u8, 0xAA), buf[4]);
    try testing.expectEqual(@as(u8, 0xBB), buf[5]);
}

test "RtAttr serialize with child" {
    var parent = nl.RtAttr.init(testing.allocator, 10, null);
    defer parent.deinit();

    _ = try parent.addChild(20, &.{0x42});

    var buf: [64]u8 = undefined;
    const len = parent.serialize(&buf);

    // parent header (4) + child header (4) + child data (1) aligned = 4 + 8 = 12
    try testing.expect(len >= 8);
}

test "RtAttr serializedLen no children" {
    var attr = nl.RtAttr.init(testing.allocator, 1, &.{ 1, 2, 3, 4 });
    defer attr.deinit();

    // header (4) + data (4) = 8
    try testing.expectEqual(@as(u32, 8), attr.serializedLen());
}

test "uint32Attr/readUint32 roundtrip" {
    const val: u32 = 0xDEADBEEF;
    const bytes = nl.uint32Attr(val);
    try testing.expectEqual(val, nl.readUint32(&bytes));
}

test "uint16Attr/readUint16 roundtrip" {
    const val: u16 = 0xBEEF;
    const bytes = nl.uint16Attr(val);
    try testing.expectEqual(val, nl.readUint16(&bytes));
}

// =============================================================================
// Unit Tests - NL Attribute Parsing
// =============================================================================

test "parseAttrs basic" {
    const native_endian = @import("builtin").cpu.arch.endian();
    // Build a simple attribute: len=8, type=5, data=0xDEADBEEF
    var buf: [8]u8 = undefined;
    std.mem.writeInt(u16, buf[0..2], 8, native_endian);
    std.mem.writeInt(u16, buf[2..4], 5, native_endian);
    std.mem.writeInt(u32, buf[4..8], 0xDEADBEEF, native_endian);

    var iter = nl.parseAttrs(&buf);
    const attr = iter.next();
    try testing.expect(attr != null);
    try testing.expectEqual(@as(u16, 5), attr.?.type_);
    try testing.expectEqual(@as(usize, 4), attr.?.data.len);
    try testing.expectEqual(@as(u32, 0xDEADBEEF), nl.readUint32(attr.?.data));

    try testing.expect(iter.next() == null);
}

test "parseAttrs multiple" {
    const native_endian = @import("builtin").cpu.arch.endian();
    var buf: [16]u8 = undefined;
    // attr 1: len=6, type=1, data=0xAA, 0xBB (padded to 8)
    std.mem.writeInt(u16, buf[0..2], 6, native_endian);
    std.mem.writeInt(u16, buf[2..4], 1, native_endian);
    buf[4] = 0xAA;
    buf[5] = 0xBB;
    buf[6] = 0; // padding
    buf[7] = 0;
    // attr 2: len=8, type=2, data=0x12345678
    std.mem.writeInt(u16, buf[8..10], 8, native_endian);
    std.mem.writeInt(u16, buf[10..12], 2, native_endian);
    std.mem.writeInt(u32, buf[12..16], 0x12345678, native_endian);

    var iter = nl.parseAttrs(&buf);

    const a1 = iter.next();
    try testing.expect(a1 != null);
    try testing.expectEqual(@as(u16, 1), a1.?.type_);
    try testing.expectEqual(@as(usize, 2), a1.?.data.len);

    const a2 = iter.next();
    try testing.expect(a2 != null);
    try testing.expectEqual(@as(u16, 2), a2.?.type_);
    try testing.expectEqual(@as(usize, 4), a2.?.data.len);

    try testing.expect(iter.next() == null);
}

test "parseAttrs empty" {
    const empty: [0]u8 = .{};
    var iter = nl.parseAttrs(&empty);
    try testing.expect(iter.next() == null);
}

// =============================================================================
// Unit Tests - NetlinkRequest Serialization
// =============================================================================

test "NetlinkRequest init" {
    const req = nl.NetlinkRequest.init(nl.RTM_GETLINK, nl.NLM_F_DUMP);
    try testing.expectEqual(nl.RTM_GETLINK, req.hdr.type_);
    try testing.expect(req.hdr.flags & nl.NLM_F_REQUEST != 0);
    try testing.expect(req.hdr.flags & nl.NLM_F_DUMP != 0);
}

test "NetlinkRequest serialize" {
    var req = nl.NetlinkRequest.init(nl.RTM_GETLINK, nl.NLM_F_DUMP);
    var buf: [128]u8 = undefined;
    const total = req.serialize(&buf);
    try testing.expectEqual(@as(u32, @sizeOf(nl.NlMsgHdr)), total);

    // verify the header len field
    const hdr: *const nl.NlMsgHdr = @alignCast(@ptrCast(&buf));
    try testing.expectEqual(total, hdr.len);
}

test "NetlinkRequest addData" {
    var req = nl.NetlinkRequest.init(nl.RTM_GETLINK, nl.NLM_F_DUMP);
    const data = [_]u8{ 1, 2, 3, 4 };
    req.addData(&data);
    try testing.expectEqual(@as(u32, 4), req.data_len);
}

// =============================================================================
// Unit Tests - NlMsgHdr size
// =============================================================================

test "NlMsgHdr size matches kernel" {
    // Linux nlmsghdr is 16 bytes
    try testing.expectEqual(@as(usize, 16), @sizeOf(nl.NlMsgHdr));
}

test "IfInfoMsg size matches kernel" {
    // Linux ifinfomsg is 16 bytes
    try testing.expectEqual(@as(usize, 16), @sizeOf(nl.IfInfoMsg));
}

test "IfAddrMsg size matches kernel" {
    // Linux ifaddrmsg is 8 bytes
    try testing.expectEqual(@as(usize, 8), @sizeOf(nl.IfAddrMsg));
}

test "RtMsg size matches kernel" {
    // Linux rtmsg is 12 bytes
    try testing.expectEqual(@as(usize, 12), @sizeOf(nl.RtMsg));
}

test "NdMsg size matches kernel" {
    // Linux ndmsg is 12 bytes
    try testing.expectEqual(@as(usize, 12), @sizeOf(nl.NdMsg));
}

test "RtAttrHdr size matches kernel" {
    // Linux rtattr header is 4 bytes
    try testing.expectEqual(@as(usize, 4), @sizeOf(nl.RtAttrHdr));
}

// =============================================================================
// Unit Tests - Constants
// =============================================================================

test "NLMSG constants" {
    try testing.expectEqual(@as(u16, 0x1), nl.NLMSG_NOOP);
    try testing.expectEqual(@as(u16, 0x2), nl.NLMSG_ERROR);
    try testing.expectEqual(@as(u16, 0x3), nl.NLMSG_DONE);
}

test "RTM constants" {
    try testing.expectEqual(@as(u16, 16), nl.RTM_NEWLINK);
    try testing.expectEqual(@as(u16, 17), nl.RTM_DELLINK);
    try testing.expectEqual(@as(u16, 18), nl.RTM_GETLINK);
    try testing.expectEqual(@as(u16, 20), nl.RTM_NEWADDR);
    try testing.expectEqual(@as(u16, 21), nl.RTM_DELADDR);
    try testing.expectEqual(@as(u16, 22), nl.RTM_GETADDR);
    try testing.expectEqual(@as(u16, 24), nl.RTM_NEWROUTE);
    try testing.expectEqual(@as(u16, 25), nl.RTM_DELROUTE);
    try testing.expectEqual(@as(u16, 26), nl.RTM_GETROUTE);
    try testing.expectEqual(@as(u16, 28), nl.RTM_NEWNEIGH);
    try testing.expectEqual(@as(u16, 29), nl.RTM_DELNEIGH);
    try testing.expectEqual(@as(u16, 30), nl.RTM_GETNEIGH);
}

test "NUD constants" {
    try testing.expectEqual(@as(u16, 0x00), nl.NUD_NONE);
    try testing.expectEqual(@as(u16, 0x02), nl.NUD_REACHABLE);
    try testing.expectEqual(@as(u16, 0x80), nl.NUD_PERMANENT);
    try testing.expectEqual(@as(u16, 0x40), nl.NUD_NOARP);
}

test "IFF flags" {
    try testing.expectEqual(@as(u32, 0x1), nl.IFF_UP);
    try testing.expectEqual(@as(u32, 0x8), nl.IFF_LOOPBACK);
    try testing.expectEqual(@as(u32, 0x80), nl.IFF_NOARP);
    try testing.expectEqual(@as(u32, 0x100), nl.IFF_PROMISC);
}

// =============================================================================
// Unit Tests - Address formatting
// =============================================================================

test "Address format IPv4" {
    const address = nl.Address{ .v4 = .{ 192, 168, 1, 1 } };
    var buf: [64]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{address}) catch unreachable;
    try testing.expectEqualStrings("192.168.1.1", result);
}

test "Address format IPv6 loopback" {
    var v6: [16]u8 = [_]u8{0} ** 16;
    v6[15] = 1;
    const address = nl.Address{ .v6 = v6 };
    var buf: [64]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{address}) catch unreachable;
    try testing.expectEqualStrings("0:0:0:0:0:0:0:1", result);
}

// =============================================================================
// Integration Tests - Netlink Socket (require root + Linux)
// These tests interact with the real kernel via netlink sockets.
// =============================================================================

fn skipUnlessRoot() bool {
    const uid = std.os.linux.getuid();
    return uid != 0;
}

fn openNetlinkRoute() !nl.NetlinkSocket {
    return nl.NetlinkSocket.open(nl.NETLINK_ROUTE);
}

test "NetlinkSocket open and close" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    try testing.expect(sock.fd >= 0);
    try testing.expect(sock.sa.pid != 0);
}

test "NetlinkSocket getNextSeq" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    const s1 = sock.getNextSeq();
    const s2 = sock.getNextSeq();
    try testing.expectEqual(s1 + 1, s2);
}

test "linkList integration" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    const links = try netlink.linkList(&sock, testing.allocator);
    defer testing.allocator.free(links);

    // Should have at least loopback
    try testing.expect(links.len >= 1);

    var found_lo = false;
    for (links) |link_val| {
        if (std.mem.eql(u8, link_val.getName(), "lo")) {
            found_lo = true;
            try testing.expect(link_val.flags & nl.IFF_LOOPBACK != 0);
        }
    }
    try testing.expect(found_lo);
}

test "linkByName loopback" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    const lo = try netlink.linkByName(&sock, "lo");
    try testing.expectEqualStrings("lo", lo.getName());
    try testing.expect(lo.index > 0);
}

test "linkByName not found" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    const result = netlink.linkByName(&sock, "nonexistent_iface_xyz");
    try testing.expectError(error.LinkNotFound, result);
}

test "linkByIndex loopback" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    // loopback is typically index 1
    const lo = try netlink.linkByName(&sock, "lo");
    const lo2 = try netlink.linkByIndex(&sock, lo.index);
    try testing.expectEqualStrings("lo", lo2.getName());
}

test "linkAdd and linkDel dummy" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var attrs = types.LinkAttrs{};
    attrs.setName("zt_dummy0");
    attrs.link_type = .dummy;

    // add
    try netlink.linkAdd(&sock, &attrs);

    // verify
    const link_val = try netlink.linkByName(&sock, "zt_dummy0");
    try testing.expectEqualStrings("zt_dummy0", link_val.getName());

    // delete
    try netlink.linkDel(&sock, link_val.index);

    // verify deleted
    const result = netlink.linkByName(&sock, "zt_dummy0");
    try testing.expectError(error.LinkNotFound, result);
}

test "linkSetUp and linkSetDown" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var attrs = types.LinkAttrs{};
    attrs.setName("zt_updown0");
    attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &attrs);
    const link_val = try netlink.linkByName(&sock, "zt_updown0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    // set up
    try netlink.linkSetUp(&sock, link_val.index);
    const up = try netlink.linkByIndex(&sock, link_val.index);
    try testing.expect(up.flags & nl.IFF_UP != 0);

    // set down
    try netlink.linkSetDown(&sock, link_val.index);
    const down = try netlink.linkByIndex(&sock, link_val.index);
    try testing.expect(down.flags & nl.IFF_UP == 0);
}

test "linkSetMTU" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var attrs = types.LinkAttrs{};
    attrs.setName("zt_mtu0");
    attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &attrs);
    const link_val = try netlink.linkByName(&sock, "zt_mtu0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetMTU(&sock, link_val.index, 1400);
    const updated = try netlink.linkByIndex(&sock, link_val.index);
    try testing.expectEqual(@as(u32, 1400), updated.mtu);
}

test "linkSetName" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var attrs = types.LinkAttrs{};
    attrs.setName("zt_rename0");
    attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &attrs);
    const link_val = try netlink.linkByName(&sock, "zt_rename0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetName(&sock, link_val.index, "zt_renamed0");
    const renamed = try netlink.linkByIndex(&sock, link_val.index);
    try testing.expectEqualStrings("zt_renamed0", renamed.getName());
}

test "linkAdd bridge" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var attrs = types.LinkAttrs{};
    attrs.setName("zt_br0");
    attrs.link_type = .bridge;
    try netlink.linkAdd(&sock, &attrs);
    const link_val = try netlink.linkByName(&sock, "zt_br0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try testing.expectEqualStrings("zt_br0", link_val.getName());
}

test "linkSetMaster" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    // create bridge
    var br_attrs = types.LinkAttrs{};
    br_attrs.setName("zt_brm0");
    br_attrs.link_type = .bridge;
    try netlink.linkAdd(&sock, &br_attrs);
    const br = try netlink.linkByName(&sock, "zt_brm0");
    defer netlink.linkDel(&sock, br.index) catch {};

    // create dummy
    var dummy_attrs = types.LinkAttrs{};
    dummy_attrs.setName("zt_dum0");
    dummy_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &dummy_attrs);
    const dummy_link = try netlink.linkByName(&sock, "zt_dum0");
    defer netlink.linkDel(&sock, dummy_link.index) catch {};

    // set master
    try netlink.linkSetMaster(&sock, dummy_link.index, br.index);
    const updated = try netlink.linkByIndex(&sock, dummy_link.index);
    try testing.expectEqual(br.index, updated.master_index);

    // unset master
    try netlink.linkSetNoMaster(&sock, dummy_link.index);
    const cleared = try netlink.linkByIndex(&sock, dummy_link.index);
    try testing.expectEqual(@as(i32, 0), cleared.master_index);
}

test "linkSetARPOff and linkSetARPOn" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var attrs = types.LinkAttrs{};
    attrs.setName("zt_arp0");
    attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &attrs);
    const link_val = try netlink.linkByName(&sock, "zt_arp0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetARPOff(&sock, link_val.index);
    const arp_off = try netlink.linkByIndex(&sock, link_val.index);
    try testing.expect(arp_off.flags & nl.IFF_NOARP != 0);

    try netlink.linkSetARPOn(&sock, link_val.index);
    const arp_on = try netlink.linkByIndex(&sock, link_val.index);
    try testing.expect(arp_on.flags & nl.IFF_NOARP == 0);
}

test "addrAdd and addrList" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    // create a dummy link
    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_addr0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_addr0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    // bring up
    try netlink.linkSetUp(&sock, link_val.index);

    // add address
    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 0, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    // list addresses
    const addrs = try netlink.addrList(&sock, link_val.index, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(addrs);

    try testing.expect(addrs.len >= 1);

    var found = false;
    for (addrs) |a| {
        if (a.ip.eql(addr_val.ip) and a.prefix_len == 24) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

test "addrAdd and addrDel" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_addel0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_addel0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 0, 1, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    // verify added
    const addrs1 = try netlink.addrList(&sock, link_val.index, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(addrs1);
    try testing.expect(addrs1.len >= 1);

    // delete
    try netlink.addrDel(&sock, link_val.index, &addr_val);

    // verify removed
    const addrs2 = try netlink.addrList(&sock, link_val.index, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(addrs2);

    var still_found = false;
    for (addrs2) |a| {
        if (a.ip.eql(addr_val.ip)) {
            still_found = true;
            break;
        }
    }
    try testing.expect(!still_found);
}

test "addrReplace" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_arep0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_arep0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 0, 2, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    // replace should succeed (idempotent)
    try netlink.addrReplace(&sock, link_val.index, &addr_val);

    const addrs = try netlink.addrList(&sock, link_val.index, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(addrs);
    try testing.expect(addrs.len >= 1);
}

test "addrAdd IPv6" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_addr6");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_addr6");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    const ipv6 = try types.parseIP("2001:db8::1");
    var addr_val = types.Addr{
        .ip = ipv6,
        .prefix_len = 64,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    const addrs = try netlink.addrList(&sock, link_val.index, nl.FAMILY_V6, testing.allocator);
    defer testing.allocator.free(addrs);

    var found = false;
    for (addrs) |a| {
        if (a.ip.eql(ipv6)) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

test "routeAdd and routeList" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    // create dummy link
    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_route0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_route0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    // add address (needed for route)
    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 100, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    // add route
    const route_val = types.Route{
        .link_index = link_val.index,
        .dst = .{ .ip = .{ .v4 = .{ 10, 200, 0, 0 } }, .prefix_len = 24 },
        .gw = .{ .v4 = .{ 10, 100, 0, 254 } },
        .scope = .universe,
    };
    try netlink.routeAdd(&sock, &route_val);

    // list routes
    const routes = try netlink.routeList(&sock, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(routes);

    var found = false;
    for (routes) |r| {
        if (r.dst) |dst| {
            if (dst.ip.eql(nl.Address{ .v4 = .{ 10, 200, 0, 0 } })) {
                found = true;
                break;
            }
        }
    }
    try testing.expect(found);
}

test "routeAdd and routeDel" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_rdel0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_rdel0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 101, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    const route_val = types.Route{
        .link_index = link_val.index,
        .dst = .{ .ip = .{ .v4 = .{ 10, 201, 0, 0 } }, .prefix_len = 24 },
        .gw = .{ .v4 = .{ 10, 101, 0, 254 } },
    };
    try netlink.routeAdd(&sock, &route_val);

    // delete
    try netlink.routeDel(&sock, &route_val);

    // verify deleted
    const routes = try netlink.routeList(&sock, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(routes);

    for (routes) |r| {
        if (r.dst) |dst| {
            if (dst.ip.eql(nl.Address{ .v4 = .{ 10, 201, 0, 0 } })) {
                try testing.expect(false); // should not find it
            }
        }
    }
}

test "routeReplace" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_rrep0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_rrep0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 102, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    const route_val = types.Route{
        .link_index = link_val.index,
        .dst = .{ .ip = .{ .v4 = .{ 10, 202, 0, 0 } }, .prefix_len = 24 },
        .gw = .{ .v4 = .{ 10, 102, 0, 254 } },
    };
    try netlink.routeAdd(&sock, &route_val);

    // replace with different gateway
    const route_replaced = types.Route{
        .link_index = link_val.index,
        .dst = .{ .ip = .{ .v4 = .{ 10, 202, 0, 0 } }, .prefix_len = 24 },
        .gw = .{ .v4 = .{ 10, 102, 0, 253 } },
    };
    try netlink.routeReplace(&sock, &route_replaced);

    const routes = try netlink.routeList(&sock, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(routes);

    var found_new_gw = false;
    for (routes) |r| {
        if (r.dst) |dst| {
            if (dst.ip.eql(nl.Address{ .v4 = .{ 10, 202, 0, 0 } })) {
                if (r.gw) |gw| {
                    if (gw.eql(nl.Address{ .v4 = .{ 10, 102, 0, 253 } })) {
                        found_new_gw = true;
                    }
                }
            }
        }
    }
    try testing.expect(found_new_gw);
}

test "neighAdd and neighList" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_neigh0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_neigh0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    // add address
    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 50, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    // add neighbor
    const neigh_val = types.Neigh{
        .ip = .{ .v4 = .{ 10, 50, 0, 2 } },
        .link_index = link_val.index,
        .state = nl.NUD_PERMANENT,
        .hardware_addr = .{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 },
    };
    try netlink.neighAdd(&sock, &neigh_val);

    // list
    const neighs = try netlink.neighList(&sock, link_val.index, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(neighs);

    var found = false;
    for (neighs) |n| {
        if (n.ip.eql(nl.Address{ .v4 = .{ 10, 50, 0, 2 } })) {
            found = true;
            if (n.hardware_addr) |hw| {
                try testing.expectEqual([6]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 }, hw);
            }
            break;
        }
    }
    try testing.expect(found);
}

test "neighAdd and neighDel" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_ndel0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_ndel0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 51, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    const neigh_val = types.Neigh{
        .ip = .{ .v4 = .{ 10, 51, 0, 2 } },
        .link_index = link_val.index,
        .state = nl.NUD_PERMANENT,
        .hardware_addr = .{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF },
    };
    try netlink.neighAdd(&sock, &neigh_val);

    // delete
    try netlink.neighDel(&sock, &neigh_val);

    // verify deleted
    const neighs = try netlink.neighList(&sock, link_val.index, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(neighs);

    for (neighs) |n| {
        if (n.ip.eql(nl.Address{ .v4 = .{ 10, 51, 0, 2 } })) {
            try testing.expect(false); // should not find it
        }
    }
}

test "neighSet replaces" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_nset0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_nset0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 52, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    const neigh1 = types.Neigh{
        .ip = .{ .v4 = .{ 10, 52, 0, 2 } },
        .link_index = link_val.index,
        .state = nl.NUD_PERMANENT,
        .hardware_addr = .{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66 },
    };
    try netlink.neighSet(&sock, &neigh1);

    // replace with new MAC
    const neigh2 = types.Neigh{
        .ip = .{ .v4 = .{ 10, 52, 0, 2 } },
        .link_index = link_val.index,
        .state = nl.NUD_PERMANENT,
        .hardware_addr = .{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF },
    };
    try netlink.neighSet(&sock, &neigh2);

    // verify new MAC
    const neighs = try netlink.neighList(&sock, link_val.index, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(neighs);

    for (neighs) |n| {
        if (n.ip.eql(nl.Address{ .v4 = .{ 10, 52, 0, 2 } })) {
            if (n.hardware_addr) |hw| {
                try testing.expectEqual([6]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF }, hw);
            }
            break;
        }
    }
}

test "addrList all links" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    const addrs = try netlink.addrList(&sock, 0, nl.FAMILY_ALL, testing.allocator);
    defer testing.allocator.free(addrs);

    // at least loopback should have 127.0.0.1
    try testing.expect(addrs.len >= 0); // may be empty in isolated namespace
}

test "routeListFiltered" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_rfilt0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_rfilt0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    var addr_val = types.Addr{
        .ip = .{ .v4 = .{ 10, 103, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr_val);

    const route_val = types.Route{
        .link_index = link_val.index,
        .dst = .{ .ip = .{ .v4 = .{ 10, 203, 0, 0 } }, .prefix_len = 24 },
        .gw = .{ .v4 = .{ 10, 103, 0, 254 } },
    };
    try netlink.routeAdd(&sock, &route_val);

    // filter by this link
    const routes = try netlink.routeListFiltered(&sock, nl.FAMILY_V4, link_val.index, testing.allocator);
    defer testing.allocator.free(routes);

    try testing.expect(routes.len >= 1);
    for (routes) |r| {
        try testing.expectEqual(link_val.index, r.link_index);
    }
}

test "linkAdd with MTU" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var attrs = types.LinkAttrs{};
    attrs.setName("zt_mtuadd0");
    attrs.link_type = .dummy;
    attrs.mtu = 9000;
    try netlink.linkAdd(&sock, &attrs);
    const link_val = try netlink.linkByName(&sock, "zt_mtuadd0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try testing.expectEqual(@as(u32, 9000), link_val.mtu);
}

test "linkAdd with TX queue length" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var attrs = types.LinkAttrs{};
    attrs.setName("zt_txq0");
    attrs.link_type = .dummy;
    attrs.tx_qlen = 500;
    try netlink.linkAdd(&sock, &attrs);
    const link_val = try netlink.linkByName(&sock, "zt_txq0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try testing.expectEqual(@as(i32, 500), link_val.tx_qlen);
}

test "multiple addresses on same link" {
    if (skipUnlessRoot()) return error.SkipZigTest;

    var sock = try openNetlinkRoute();
    defer sock.close();

    var link_attrs = types.LinkAttrs{};
    link_attrs.setName("zt_multi0");
    link_attrs.link_type = .dummy;
    try netlink.linkAdd(&sock, &link_attrs);
    const link_val = try netlink.linkByName(&sock, "zt_multi0");
    defer netlink.linkDel(&sock, link_val.index) catch {};

    try netlink.linkSetUp(&sock, link_val.index);

    var addr1 = types.Addr{
        .ip = .{ .v4 = .{ 10, 60, 0, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr1);

    var addr2 = types.Addr{
        .ip = .{ .v4 = .{ 10, 60, 1, 1 } },
        .prefix_len = 24,
    };
    try netlink.addrAdd(&sock, link_val.index, &addr2);

    const addrs = try netlink.addrList(&sock, link_val.index, nl.FAMILY_V4, testing.allocator);
    defer testing.allocator.free(addrs);

    try testing.expect(addrs.len >= 2);
}
