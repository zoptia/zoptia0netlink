const std = @import("std");
const nl = @import("nl.zig");
const types = @import("types.zig");
const native_endian = @import("builtin").cpu.arch.endian();

pub const AddrError = error{
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

// addrAdd adds an IP address to a link device.
// Equivalent to: `ip addr add $addr dev $link`
pub fn addrAdd(sock: *nl.NetlinkSocket, link_index: i32, addr: *const types.Addr) AddrError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_NEWADDR, nl.NLM_F_CREATE | nl.NLM_F_EXCL | nl.NLM_F_ACK);
    return addrHandle(sock, link_index, addr, &req);
}

// addrReplace replaces (or adds if not present) an IP address on a link.
// Equivalent to: `ip addr replace $addr dev $link`
pub fn addrReplace(sock: *nl.NetlinkSocket, link_index: i32, addr: *const types.Addr) AddrError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_NEWADDR, nl.NLM_F_CREATE | nl.NLM_F_REPLACE | nl.NLM_F_ACK);
    return addrHandle(sock, link_index, addr, &req);
}

// addrDel deletes an IP address from a link device.
// Equivalent to: `ip addr del $addr dev $link`
pub fn addrDel(sock: *nl.NetlinkSocket, link_index: i32, addr: *const types.Addr) AddrError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_DELADDR, nl.NLM_F_ACK);
    return addrHandle(sock, link_index, addr, &req);
}

fn addrHandle(sock: *nl.NetlinkSocket, link_index: i32, addr: *const types.Addr, req: *nl.NetlinkRequest) AddrError!void {
    const family = nl.getIPFamily(addr.ip);

    var msg = nl.IfAddrMsg{
        .family = family,
        .prefixlen = addr.prefix_len,
        .scope = addr.scope,
        .index = @bitCast(link_index),
    };

    if (addr.flags <= 0xFF) {
        msg.flags = @intCast(addr.flags);
    }

    req.addData(std.mem.asBytes(&msg));

    // IFA_LOCAL
    const ip_bytes = addr.ip.toBytes();
    var local_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFA_LOCAL, ip_bytes);
    defer local_attr.deinit();
    req.addRtAttr(&local_attr);

    // IFA_ADDRESS (peer or same as local)
    const peer_bytes = if (addr.peer) |peer| peer.ip.toBytes() else ip_bytes;
    var addr_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFA_ADDRESS, peer_bytes);
    defer addr_attr.deinit();
    req.addRtAttr(&addr_attr);

    // IFA_FLAGS for flags > 0xFF
    if (addr.flags > 0xFF) {
        const flags_val = nl.uint32Attr(addr.flags);
        var flags_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFA_FLAGS, &flags_val);
        defer flags_attr.deinit();
        req.addRtAttr(&flags_attr);
    }

    // Broadcast (auto-compute for IPv4 if not set and prefix < 31)
    if (family == nl.FAMILY_V4) {
        if (addr.broadcast) |bcast| {
            var bcast_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFA_BROADCAST, bcast.toBytes());
            defer bcast_attr.deinit();
            req.addRtAttr(&bcast_attr);
        } else if (addr.prefix_len < 31) {
            switch (addr.ip) {
                .v4 => |v4| {
                    const bcast = types.computeBroadcast(v4, addr.prefix_len);
                    var bcast_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFA_BROADCAST, &bcast);
                    defer bcast_attr.deinit();
                    req.addRtAttr(&bcast_attr);
                },
                .v6 => {},
            }
        }

        // Label
        const lbl = addr.getLabel();
        if (lbl.len > 0) {
            var label_buf: [17]u8 = [_]u8{0} ** 17;
            @memcpy(label_buf[0..lbl.len], lbl);
            label_buf[lbl.len] = 0;
            var label_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFA_LABEL, label_buf[0 .. lbl.len + 1]);
            defer label_attr.deinit();
            req.addRtAttr(&label_attr);
        }
    }

    // Cache info for lifetime
    if (addr.valid_lft > 0 or addr.preferred_lft > 0) {
        const cache = nl.IfaCacheInfo{
            .prefered = addr.preferred_lft,
            .valid = addr.valid_lft,
        };
        var cache_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFA_CACHEINFO, std.mem.asBytes(&cache));
        defer cache_attr.deinit();
        req.addRtAttr(&cache_attr);
    }

    // IFA_PROTO
    if (addr.protocol != 0) {
        const proto_val = nl.uint8Attr(addr.protocol);
        var proto_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFA_PROTO, &proto_val);
        defer proto_attr.deinit();
        req.addRtAttr(&proto_attr);
    }

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// addrList gets a list of IP addresses.
// Equivalent to: `ip addr show`
pub fn addrList(sock: *nl.NetlinkSocket, link_index: i32, family: u8, allocator: std.mem.Allocator) ![]types.Addr {
    var req = nl.NetlinkRequest.init(nl.RTM_GETADDR, nl.NLM_F_DUMP);

    var msg = nl.IfAddrMsg{
        .family = family,
    };
    // Ask the kernel to filter by ifindex when possible. Requires
    // NETLINK_GET_STRICT_CHK on the socket; otherwise the kernel ignores
    // this field and the userspace filter below serves as fallback.
    if (link_index != 0) {
        msg.index = @bitCast(link_index);
    }
    req.addData(std.mem.asBytes(&msg));

    const msgs = try req.executeAlloc(sock, allocator);
    defer {
        for (msgs) |item| allocator.free(item);
        allocator.free(msgs);
    }

    var addrs: std.ArrayList(types.Addr) = .empty;
    errdefer addrs.deinit(allocator);

    for (msgs) |data| {
        if (data.len < @sizeOf(nl.IfAddrMsg)) continue;

        var addr_msg_buf: nl.IfAddrMsg = undefined;
        @memcpy(std.mem.asBytes(&addr_msg_buf), data[0..@sizeOf(nl.IfAddrMsg)]);
        const addr_msg = &addr_msg_buf;

        // filter by link index (0 = all)
        if (link_index != 0 and @as(i32, @bitCast(addr_msg.index)) != link_index) continue;

        var addr = types.Addr{
            .ip = .{ .v4 = .{ 0, 0, 0, 0 } },
            .prefix_len = addr_msg.prefixlen,
            .scope = addr_msg.scope,
            .link_index = @bitCast(addr_msg.index),
        };
        addr.flags = addr_msg.flags;

        // parse attributes
        const attr_data = data[@sizeOf(nl.IfAddrMsg)..];
        var iter = nl.parseAttrs(attr_data);
        var has_local = false;

        while (iter.next()) |attr| {
            switch (attr.type_) {
                nl.IFA_ADDRESS => {
                    if (!has_local) {
                        addr.ip = nl.Address.fromSlice(attr.data) catch continue;
                    }
                    if (attr.data.len == 4 or attr.data.len == 16) {
                        // might be peer address if different from local
                    }
                },
                nl.IFA_LOCAL => {
                    addr.ip = nl.Address.fromSlice(attr.data) catch continue;
                    has_local = true;
                },
                nl.IFA_LABEL => {
                    const end = std.mem.indexOfScalar(u8, attr.data, 0) orelse attr.data.len;
                    addr.setLabel(attr.data[0..end]);
                },
                nl.IFA_BROADCAST => {
                    addr.broadcast = nl.Address.fromSlice(attr.data) catch null;
                },
                nl.IFA_CACHEINFO => {
                    if (attr.data.len >= @sizeOf(nl.IfaCacheInfo)) {
                        var cache: nl.IfaCacheInfo = undefined;
                        @memcpy(std.mem.asBytes(&cache), attr.data[0..@sizeOf(nl.IfaCacheInfo)]);
                        addr.preferred_lft = cache.prefered;
                        addr.valid_lft = cache.valid;
                    }
                },
                nl.IFA_FLAGS => {
                    if (attr.data.len >= 4) addr.flags = nl.readUint32(attr.data);
                },
                nl.IFA_PROTO => {
                    if (attr.data.len >= 1) addr.protocol = attr.data[0];
                },
                else => {},
            }
        }

        try addrs.append(allocator, addr);
    }

    return try addrs.toOwnedSlice(allocator);
}
