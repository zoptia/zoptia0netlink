const std = @import("std");
const nl = @import("nl.zig");
const types = @import("types.zig");
const native_endian = @import("builtin").cpu.arch.endian();

pub const RouteError = error{
    NetlinkError,
    SendFailed,
    ShortRead,
    WrongSenderPid,
    InvalidMessage,
    GetSockNameFailed,
    OutOfMemory,
    SocketError,
    Unexpected,
} || std.posix.SocketError || std.posix.BindError;

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

    var routes: std.ArrayList(types.Route) = .{};
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

    var routes: std.ArrayList(types.Route) = .{};
    errdefer routes.deinit(allocator);

    for (all_routes) |route_val| {
        if (link_index == 0 or route_val.link_index == link_index) {
            try routes.append(allocator, route_val);
        }
    }

    return try routes.toOwnedSlice(allocator);
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
            else => {},
        }
    }

    return route;
}
