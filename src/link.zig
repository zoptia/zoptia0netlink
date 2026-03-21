const std = @import("std");
const nl = @import("nl.zig");
const types = @import("types.zig");
const native_endian = @import("builtin").cpu.arch.endian();

pub const LinkAddError = error{
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

pub const LinkError = LinkAddError || error{
    LinkNotFound,
};

// linkAdd adds a new link device.
// Equivalent to: `ip link add $link`
pub fn linkAdd(sock: *nl.NetlinkSocket, attrs: *const types.LinkAttrs) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_NEWLINK, nl.NLM_F_CREATE | nl.NLM_F_EXCL | nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
    };
    req.addData(std.mem.asBytes(&msg));

    // name attribute
    var name_buf: [17]u8 = [_]u8{0} ** 17;
    const name = attrs.getName();
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;
    var name_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_IFNAME, name_buf[0 .. name.len + 1]);
    defer name_attr.deinit();
    req.addRtAttr(&name_attr);

    // MTU
    if (attrs.mtu > 0) {
        const mtu_val = nl.uint32Attr(attrs.mtu);
        var mtu_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_MTU, &mtu_val);
        defer mtu_attr.deinit();
        req.addRtAttr(&mtu_attr);
    }

    // TX queue length
    if (attrs.tx_qlen >= 0) {
        const qlen_val = nl.uint32Attr(@bitCast(attrs.tx_qlen));
        var qlen_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_TXQLEN, &qlen_val);
        defer qlen_attr.deinit();
        req.addRtAttr(&qlen_attr);
    }

    // Num TX/RX queues
    if (attrs.num_tx_queues > 0) {
        const val = nl.uint32Attr(attrs.num_tx_queues);
        var attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_NUM_TX_QUEUES, &val);
        defer attr.deinit();
        req.addRtAttr(&attr);
    }
    if (attrs.num_rx_queues > 0) {
        const val = nl.uint32Attr(attrs.num_rx_queues);
        var attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_NUM_RX_QUEUES, &val);
        defer attr.deinit();
        req.addRtAttr(&attr);
    }

    // Hardware address
    if (attrs.hardware_addr) |hw| {
        var hw_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_ADDRESS, &hw);
        defer hw_attr.deinit();
        req.addRtAttr(&hw_attr);
    }

    // Group
    if (attrs.group > 0) {
        const val = nl.uint32Attr(attrs.group);
        var attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_GROUP, &val);
        defer attr.deinit();
        req.addRtAttr(&attr);
    }

    // Link info (type-specific)
    if (attrs.link_type != .device) {
        addLinkInfo(&req, attrs);
    }

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

fn addLinkInfo(req: *nl.NetlinkRequest, attrs: *const types.LinkAttrs) void {
    // build IFLA_LINKINFO manually
    const kind_name = attrs.link_type.toString();

    // IFLA_INFO_KIND attribute
    var kind_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_INFO_KIND, kind_name);
    defer kind_attr.deinit();

    // IFLA_LINKINFO container (nested)
    var linkinfo = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_LINKINFO, null);
    defer linkinfo.deinit();

    // Serialize kind_attr into linkinfo's data
    var kind_buf: [256]u8 = undefined;
    const kind_len = kind_attr.serialize(&kind_buf);

    // Now build the linkinfo attr manually
    var li_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_LINKINFO | nl.NLA_F_NESTED, kind_buf[0..kind_len]);
    defer li_attr.deinit();

    req.addRtAttr(&li_attr);
}

// linkDel removes a link device.
// Equivalent to: `ip link del $link`
pub fn linkDel(sock: *nl.NetlinkSocket, index: i32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_DELLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
    };
    req.addData(std.mem.asBytes(&msg));

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkList retrieves all link devices.
// Equivalent to: `ip link show`
pub fn linkList(sock: *nl.NetlinkSocket, allocator: std.mem.Allocator) ![]types.LinkAttrs {
    var req = nl.NetlinkRequest.init(nl.RTM_GETLINK, nl.NLM_F_DUMP);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
    };
    req.addData(std.mem.asBytes(&msg));

    const msgs = try req.executeAlloc(sock, allocator);
    defer {
        for (msgs) |item| allocator.free(item);
        allocator.free(msgs);
    }

    var links: std.ArrayList(types.LinkAttrs) = .{};
    errdefer links.deinit(allocator);

    for (msgs) |data| {
        if (data.len < @sizeOf(nl.IfInfoMsg)) continue;
        const link_val = parseLinkMsg(data);
        try links.append(allocator, link_val);
    }

    return try links.toOwnedSlice(allocator);
}

fn parseLinkMsg(data: []const u8) types.LinkAttrs {
    var attrs = types.LinkAttrs{};

    if (data.len < @sizeOf(nl.IfInfoMsg)) return attrs;

    var info: nl.IfInfoMsg = undefined;
    @memcpy(std.mem.asBytes(&info), data[0..@sizeOf(nl.IfInfoMsg)]);
    attrs.index = info.index;
    attrs.raw_flags = info.flags;
    attrs.flags = info.flags;

    // parse attributes
    const attr_data = data[@sizeOf(nl.IfInfoMsg)..];
    var iter = nl.parseAttrs(attr_data);
    while (iter.next()) |attr| {
        switch (attr.type_) {
            nl.IFLA_IFNAME => {
                const name_end = std.mem.indexOfScalar(u8, attr.data, 0) orelse attr.data.len;
                const len = @min(name_end, attrs.name.len - 1);
                @memcpy(attrs.name[0..len], attr.data[0..len]);
                attrs.name_len = @intCast(len);
            },
            nl.IFLA_MTU => {
                if (attr.data.len >= 4) attrs.mtu = nl.readUint32(attr.data);
            },
            nl.IFLA_TXQLEN => {
                if (attr.data.len >= 4) attrs.tx_qlen = nl.readInt32(attr.data);
            },
            nl.IFLA_MASTER => {
                if (attr.data.len >= 4) attrs.master_index = nl.readInt32(attr.data);
            },
            nl.IFLA_LINK => {
                if (attr.data.len >= 4) attrs.parent_index = nl.readInt32(attr.data);
            },
            nl.IFLA_OPERSTATE => {
                if (attr.data.len >= 1) attrs.oper_state = @enumFromInt(attr.data[0]);
            },
            nl.IFLA_ADDRESS => {
                if (attr.data.len == 6) {
                    attrs.hardware_addr = attr.data[0..6].*;
                }
            },
            nl.IFLA_GROUP => {
                if (attr.data.len >= 4) attrs.group = nl.readUint32(attr.data);
            },
            nl.IFLA_NUM_TX_QUEUES => {
                if (attr.data.len >= 4) attrs.num_tx_queues = nl.readUint32(attr.data);
            },
            nl.IFLA_NUM_RX_QUEUES => {
                if (attr.data.len >= 4) attrs.num_rx_queues = nl.readUint32(attr.data);
            },
            nl.IFLA_GSO_MAX_SEGS => {
                if (attr.data.len >= 4) attrs.gso_max_segs = nl.readUint32(attr.data);
            },
            nl.IFLA_GSO_MAX_SIZE => {
                if (attr.data.len >= 4) attrs.gso_max_size = nl.readUint32(attr.data);
            },
            nl.IFLA_GRO_MAX_SIZE => {
                if (attr.data.len >= 4) attrs.gro_max_size = nl.readUint32(attr.data);
            },
            nl.IFLA_PROMISCUITY => {
                if (attr.data.len >= 4) attrs.promisc = nl.readUint32(attr.data);
            },
            nl.IFLA_LINKINFO => {
                parseLinkInfo(attr.data, &attrs);
            },
            nl.IFLA_STATS64 => {
                if (attr.data.len >= @sizeOf(types.LinkStatistics64)) {
                    var stats: types.LinkStatistics64 = undefined;
                    @memcpy(std.mem.asBytes(&stats), attr.data[0..@sizeOf(types.LinkStatistics64)]);
                    attrs.statistics = stats;
                }
            },
            nl.IFLA_IFALIAS => {
                const end = std.mem.indexOfScalar(u8, attr.data, 0) orelse attr.data.len;
                const len = @min(end, attrs.alias.len - 1);
                @memcpy(attrs.alias[0..len], attr.data[0..len]);
                attrs.alias_len = @intCast(len);
            },
            else => {},
        }
    }

    return attrs;
}

fn parseLinkInfo(data: []const u8, attrs: *types.LinkAttrs) void {
    var iter = nl.parseAttrs(data);
    while (iter.next()) |attr| {
        switch (attr.type_) {
            nl.IFLA_INFO_KIND => {
                const end = std.mem.indexOfScalar(u8, attr.data, 0) orelse attr.data.len;
                attrs.link_type = types.LinkType.fromString(attr.data[0..end]);
            },
            else => {},
        }
    }
}

// linkByName finds a link by name.
// Equivalent to: `ip link show $name`
pub fn linkByName(sock: *nl.NetlinkSocket, name: []const u8) LinkError!types.LinkAttrs {
    const links = linkList(sock, std.heap.page_allocator) catch return error.NetlinkError;
    defer std.heap.page_allocator.free(links);

    for (links) |link| {
        if (std.mem.eql(u8, link.getName(), name)) {
            return link;
        }
    }
    return error.LinkNotFound;
}

// linkByIndex finds a link by index.
pub fn linkByIndex(sock: *nl.NetlinkSocket, index: i32) LinkError!types.LinkAttrs {
    const links = linkList(sock, std.heap.page_allocator) catch return error.NetlinkError;
    defer std.heap.page_allocator.free(links);

    for (links) |link| {
        if (link.index == index) {
            return link;
        }
    }
    return error.LinkNotFound;
}

// linkSetUp brings a link up.
// Equivalent to: `ip link set $link up`
pub fn linkSetUp(sock: *nl.NetlinkSocket, index: i32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_NEWLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
        .flags = nl.IFF_UP,
        .change = nl.IFF_UP,
    };
    req.addData(std.mem.asBytes(&msg));

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetDown brings a link down.
// Equivalent to: `ip link set $link down`
pub fn linkSetDown(sock: *nl.NetlinkSocket, index: i32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_NEWLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
        .change = nl.IFF_UP,
    };
    req.addData(std.mem.asBytes(&msg));

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetMTU sets the MTU of a link.
// Equivalent to: `ip link set $link mtu $mtu`
pub fn linkSetMTU(sock: *nl.NetlinkSocket, index: i32, mtu: u32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_SETLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
    };
    req.addData(std.mem.asBytes(&msg));

    const mtu_val = nl.uint32Attr(mtu);
    var mtu_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_MTU, &mtu_val);
    defer mtu_attr.deinit();
    req.addRtAttr(&mtu_attr);

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetName renames a link.
// Equivalent to: `ip link set $link name $name`
pub fn linkSetName(sock: *nl.NetlinkSocket, index: i32, name: []const u8) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_SETLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
    };
    req.addData(std.mem.asBytes(&msg));

    var name_buf: [17]u8 = [_]u8{0} ** 17;
    const len = @min(name.len, 15);
    @memcpy(name_buf[0..len], name[0..len]);
    name_buf[len] = 0;

    var name_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_IFNAME, name_buf[0 .. len + 1]);
    defer name_attr.deinit();
    req.addRtAttr(&name_attr);

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetMaster assigns a master device.
// Equivalent to: `ip link set $link master $master`
pub fn linkSetMaster(sock: *nl.NetlinkSocket, index: i32, master_index: i32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_SETLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
    };
    req.addData(std.mem.asBytes(&msg));

    const val = nl.uint32Attr(@bitCast(master_index));
    var attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_MASTER, &val);
    defer attr.deinit();
    req.addRtAttr(&attr);

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetNoMaster removes the master device.
// Equivalent to: `ip link set $link nomaster`
pub fn linkSetNoMaster(sock: *nl.NetlinkSocket, index: i32) LinkAddError!void {
    return linkSetMaster(sock, index, 0);
}

// linkSetARPOff disables ARP on a link.
pub fn linkSetARPOff(sock: *nl.NetlinkSocket, index: i32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_SETLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
        .flags = nl.IFF_NOARP,
        .change = nl.IFF_NOARP,
    };
    req.addData(std.mem.asBytes(&msg));

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetARPOn enables ARP on a link.
pub fn linkSetARPOn(sock: *nl.NetlinkSocket, index: i32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_SETLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
        .change = nl.IFF_NOARP,
    };
    req.addData(std.mem.asBytes(&msg));

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetPromiscOn enables promiscuous mode.
pub fn linkSetPromiscOn(sock: *nl.NetlinkSocket, index: i32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_SETLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
        .flags = nl.IFF_PROMISC,
        .change = nl.IFF_PROMISC,
    };
    req.addData(std.mem.asBytes(&msg));

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetPromiscOff disables promiscuous mode.
pub fn linkSetPromiscOff(sock: *nl.NetlinkSocket, index: i32) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_SETLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
        .change = nl.IFF_PROMISC,
    };
    req.addData(std.mem.asBytes(&msg));

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// linkSetHardwareAddr sets the hardware (MAC) address.
pub fn linkSetHardwareAddr(sock: *nl.NetlinkSocket, index: i32, hw_addr: [6]u8) LinkAddError!void {
    var req = nl.NetlinkRequest.init(nl.RTM_SETLINK, nl.NLM_F_ACK);

    var msg = nl.IfInfoMsg{
        .family = nl.FAMILY_ALL,
        .index = index,
    };
    req.addData(std.mem.asBytes(&msg));

    var hw_attr = nl.RtAttr.init(std.heap.page_allocator, nl.IFLA_ADDRESS, &hw_addr);
    defer hw_attr.deinit();
    req.addRtAttr(&hw_attr);

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}
