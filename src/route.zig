const std = @import("std");
const nl = @import("nl.zig");
const types = @import("types.zig");
const native_endian = @import("builtin").cpu.arch.endian();

pub const RouteError = error{
    NetlinkError,
    SocketOpenFailed,
    BindFailed,
    SendFailed,
    RecvFailed,
    ShortRead,
    WrongSenderPid,
    InvalidMessage,
    GetSockNameFailed,
    OutOfMemory,
    SocketError,
    DumpInterrupted,
    Unexpected,
};

// routeAdd adds a new route.
// Equivalent to: `ip route add $route`
pub fn routeAdd(sock: *nl.NetlinkSocket, route: *const types.Route) RouteError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_NEWROUTE, nl.NLM_F_CREATE | nl.NLM_F_EXCL | nl.NLM_F_ACK);
    return routeHandle(sock, route, &req);
}

// routeReplace adds or replaces a route.
// Equivalent to: `ip route replace $route`
pub fn routeReplace(sock: *nl.NetlinkSocket, route: *const types.Route) RouteError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_NEWROUTE, nl.NLM_F_CREATE | nl.NLM_F_REPLACE | nl.NLM_F_ACK);
    return routeHandle(sock, route, &req);
}

// routeDel removes a route.
// Equivalent to: `ip route del $route`
pub fn routeDel(sock: *nl.NetlinkSocket, route: *const types.Route) RouteError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_DELROUTE, nl.NLM_F_ACK);
    return routeHandle(sock, route, &req);
}

fn routeHandle(sock: *nl.NetlinkSocket, route: *const types.Route, req: *nl.NetlinkRequest) RouteError!void {
    var family: u8 = route.family;
    if (family == 0) {
        if (route.dst) |dst| {
            family = nl.getIPFamily(dst.ip);
        } else if (route.gw) |gw| {
            family = nl.getIPFamily(gw);
        } else if (route.src) |src| {
            family = nl.getIPFamily(src);
        } else {
            family = nl.FAMILY_V4;
        }
    }

    var msg = nl.RtMsg{
        .family = family,
        .table = @intCast(route.table & 0xFF),
        .protocol = @intFromEnum(route.protocol),
        .scope = @intFromEnum(route.scope),
        .type_ = route.type_,
        .flags = route.flags,
    };

    if (route.dst) |dst| {
        msg.dst_len = dst.prefix_len;
    }

    req.addData(std.mem.asBytes(&msg));

    // RTA_DST
    if (route.dst) |dst| {
        var dst_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_DST, dst.ip.toBytes());
        defer dst_attr.deinit();
        req.addRtAttr(&dst_attr);
    }

    // RTA_SRC
    if (route.src) |src| {
        var src_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_PREFSRC, src.toBytes());
        defer src_attr.deinit();
        req.addRtAttr(&src_attr);
    }

    // RTA_GATEWAY
    if (route.gw) |gw| {
        var gw_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_GATEWAY, gw.toBytes());
        defer gw_attr.deinit();
        req.addRtAttr(&gw_attr);
    }

    // RTA_OIF
    if (route.link_index != 0) {
        const val = nl.uint32Attr(@bitCast(route.link_index));
        var oif_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_OIF, &val);
        defer oif_attr.deinit();
        req.addRtAttr(&oif_attr);
    }

    // RTA_PRIORITY
    if (route.priority > 0) {
        const val = nl.uint32Attr(route.priority);
        var prio_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_PRIORITY, &val);
        defer prio_attr.deinit();
        req.addRtAttr(&prio_attr);
    }

    // RTA_TABLE (extended)
    if (route.table >= 256) {
        const val = nl.uint32Attr(route.table);
        var table_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_TABLE, &val);
        defer table_attr.deinit();
        req.addRtAttr(&table_attr);
    }

    // RTA_EXPIRES (lifetime in seconds, kernel ignores 0)
    if (route.expires) |expires| {
        const val = nl.uint32Attr(expires);
        var exp_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_EXPIRES, &val);
        defer exp_attr.deinit();
        req.addRtAttr(&exp_attr);
    }

    // RTA_ENCAP_TYPE + RTA_ENCAP for IP6 LWT tunnel encapsulation.
    if (route.encap_ip6) |encap| {
        const type_val = nl.uint16Attr(nl.LWTUNNEL_ENCAP_IP6);
        var type_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_ENCAP_TYPE, &type_val);
        defer type_attr.deinit();
        req.addRtAttr(&type_attr);

        var encap_buf: [128]u8 = undefined;
        const encap_len = encodeIp6tnlEncap(&encap_buf, encap);
        var encap_attr = nl.RtAttr.init(std.heap.page_allocator, nl.RTA_ENCAP | nl.NLA_F_NESTED, encap_buf[0..encap_len]);
        defer encap_attr.deinit();
        req.addRtAttr(&encap_attr);
    }

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// routeList gets a list of routes.
// Equivalent to: `ip route show`
pub fn routeList(sock: *nl.NetlinkSocket, family: u8, allocator: std.mem.Allocator) ![]types.Route {
    var req = nl.NetlinkRequest.init(nl.RTM_GETROUTE, nl.NLM_F_DUMP);

    var msg = nl.RtMsg{
        .family = family,
    };
    req.addData(std.mem.asBytes(&msg));

    const msgs = try req.executeAlloc(sock, allocator);
    defer {
        for (msgs) |item| allocator.free(item);
        allocator.free(msgs);
    }

    var routes: std.ArrayList(types.Route) = .empty;
    errdefer routes.deinit(allocator);

    for (msgs) |data| {
        if (data.len < @sizeOf(nl.RtMsg)) continue;
        const route_val = parseRouteMsg(data);
        try routes.append(allocator, route_val);
    }

    return try routes.toOwnedSlice(allocator);
}

// routeListFiltered gets routes filtered by link index.
pub fn routeListFiltered(sock: *nl.NetlinkSocket, family: u8, link_index: i32, allocator: std.mem.Allocator) ![]types.Route {
    const all_routes = try routeList(sock, family, allocator);
    defer allocator.free(all_routes);

    var routes: std.ArrayList(types.Route) = .empty;
    errdefer routes.deinit(allocator);

    for (all_routes) |route_val| {
        if (link_index == 0 or route_val.link_index == link_index) {
            try routes.append(allocator, route_val);
        }
    }

    return try routes.toOwnedSlice(allocator);
}

// Serialize an Ip6tnlEncap as a sequence of LWTUNNEL_IP6_* attributes into
// `buf`, matching the wire format used by the kernel (ID and FLAGS in network
// byte order). Returns the number of bytes written.
fn encodeIp6tnlEncap(buf: []u8, encap: types.Ip6tnlEncap) u32 {
    const alloc = std.heap.page_allocator;
    var off: u32 = 0;

    // LWTUNNEL_IP6_ID (u64, big-endian on the wire).
    var id_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &id_buf, encap.id, .big);
    var id_attr = nl.RtAttr.init(alloc, nl.LWTUNNEL_IP6_ID, &id_buf);
    off += nl.rtaAlign(id_attr.serialize(buf[off..]));
    id_attr.deinit();

    if (encap.dst) |dst| {
        var dst_attr = nl.RtAttr.init(alloc, nl.LWTUNNEL_IP6_DST, &dst);
        off += nl.rtaAlign(dst_attr.serialize(buf[off..]));
        dst_attr.deinit();
    }
    if (encap.src) |src| {
        var src_attr = nl.RtAttr.init(alloc, nl.LWTUNNEL_IP6_SRC, &src);
        off += nl.rtaAlign(src_attr.serialize(buf[off..]));
        src_attr.deinit();
    }

    const hop = nl.uint8Attr(encap.hoplimit);
    var hop_attr = nl.RtAttr.init(alloc, nl.LWTUNNEL_IP6_HOPLIMIT, &hop);
    off += nl.rtaAlign(hop_attr.serialize(buf[off..]));
    hop_attr.deinit();

    const tc = nl.uint8Attr(encap.tc);
    var tc_attr = nl.RtAttr.init(alloc, nl.LWTUNNEL_IP6_TC, &tc);
    off += nl.rtaAlign(tc_attr.serialize(buf[off..]));
    tc_attr.deinit();

    // FLAGS is u16, network byte order.
    const flags_be = nl.uint16AttrBE(encap.flags);
    var flags_attr = nl.RtAttr.init(alloc, nl.LWTUNNEL_IP6_FLAGS, &flags_be);
    off += nl.rtaAlign(flags_attr.serialize(buf[off..]));
    flags_attr.deinit();

    return off;
}

fn decodeIp6tnlEncap(data: []const u8) types.Ip6tnlEncap {
    var encap = types.Ip6tnlEncap{};
    var iter = nl.parseAttrs(data);
    while (iter.next()) |attr| {
        switch (attr.type_) {
            nl.LWTUNNEL_IP6_ID => {
                if (attr.data.len >= 8) {
                    encap.id = std.mem.readInt(u64, attr.data[0..8], .big);
                }
            },
            nl.LWTUNNEL_IP6_DST => {
                if (attr.data.len == 16) encap.dst = attr.data[0..16].*;
            },
            nl.LWTUNNEL_IP6_SRC => {
                if (attr.data.len == 16) encap.src = attr.data[0..16].*;
            },
            nl.LWTUNNEL_IP6_HOPLIMIT => {
                if (attr.data.len >= 1) encap.hoplimit = attr.data[0];
            },
            nl.LWTUNNEL_IP6_TC => {
                if (attr.data.len >= 1) encap.tc = attr.data[0];
            },
            nl.LWTUNNEL_IP6_FLAGS => {
                if (attr.data.len >= 2) {
                    encap.flags = std.mem.readInt(u16, attr.data[0..2], .big);
                }
            },
            else => {},
        }
    }
    return encap;
}

fn parseRouteMsg(data: []const u8) types.Route {
    var route = types.Route{};

    if (data.len < @sizeOf(nl.RtMsg)) return route;

    var msg_buf: nl.RtMsg = undefined;
    @memcpy(std.mem.asBytes(&msg_buf), data[0..@sizeOf(nl.RtMsg)]);
    const msg = &msg_buf;
    route.scope = @enumFromInt(msg.scope);
    route.protocol = @enumFromInt(msg.protocol);
    route.type_ = msg.type_;
    route.tos = msg.tos;
    route.flags = msg.flags;
    route.table = msg.table;
    route.family = msg.family;

    const attr_data = data[@sizeOf(nl.RtMsg)..];
    var iter = nl.parseAttrs(attr_data);

    while (iter.next()) |attr| {
        switch (attr.type_) {
            nl.RTA_DST => {
                const ip = nl.Address.fromSlice(attr.data) catch continue;
                route.dst = .{ .ip = ip, .prefix_len = msg.dst_len };
            },
            nl.RTA_SRC, nl.RTA_PREFSRC => {
                route.src = nl.Address.fromSlice(attr.data) catch null;
            },
            nl.RTA_GATEWAY => {
                route.gw = nl.Address.fromSlice(attr.data) catch null;
            },
            nl.RTA_OIF => {
                if (attr.data.len >= 4) route.link_index = nl.readInt32(attr.data);
            },
            nl.RTA_PRIORITY => {
                if (attr.data.len >= 4) route.priority = nl.readUint32(attr.data);
            },
            nl.RTA_TABLE => {
                if (attr.data.len >= 4) route.table = nl.readUint32(attr.data);
            },
            nl.RTA_EXPIRES => {
                if (attr.data.len >= 4) route.expires = nl.readUint32(attr.data);
            },
            nl.RTA_ENCAP_TYPE => {
                // Captured for later use; actual decode happens on RTA_ENCAP.
            },
            nl.RTA_ENCAP => {
                // Only IP6 LWT encap is decoded; other encap types are ignored.
                route.encap_ip6 = decodeIp6tnlEncap(attr.data);
            },
            else => {},
        }
    }

    return route;
}
