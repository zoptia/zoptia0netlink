const std = @import("std");
const nl = @import("nl.zig");
const types = @import("types.zig");
const native_endian = @import("builtin").cpu.arch.endian();

pub const NeighError = error{
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

// neighAdd adds an IP to MAC mapping to the ARP table.
// Equivalent to: `ip neigh add ...`
pub fn neighAdd(sock: *nl.NetlinkSocket, neigh: *const types.Neigh) NeighError!void {
    return neighModify(sock, neigh, nl.RTM_NEWNEIGH, nl.NLM_F_CREATE | nl.NLM_F_EXCL | nl.NLM_F_ACK);
}

// neighSet will add or replace an IP to MAC mapping.
// Equivalent to: `ip neigh replace ...`
pub fn neighSet(sock: *nl.NetlinkSocket, neigh: *const types.Neigh) NeighError!void {
    return neighModify(sock, neigh, nl.RTM_NEWNEIGH, nl.NLM_F_CREATE | nl.NLM_F_REPLACE | nl.NLM_F_ACK);
}

// neighAppend appends an entry to FDB.
// Equivalent to: `bridge fdb append ...`
pub fn neighAppend(sock: *nl.NetlinkSocket, neigh: *const types.Neigh) NeighError!void {
    return neighModify(sock, neigh, nl.RTM_NEWNEIGH, nl.NLM_F_CREATE | nl.NLM_F_APPEND | nl.NLM_F_ACK);
}

// neighDel deletes a neighbor entry.
// Equivalent to: `ip neigh del ...`
pub fn neighDel(sock: *nl.NetlinkSocket, neigh: *const types.Neigh) NeighError!void {
    return neighModify(sock, neigh, nl.RTM_DELNEIGH, nl.NLM_F_ACK);
}

fn neighModify(sock: *nl.NetlinkSocket, neigh: *const types.Neigh, msg_type: u16, flags: u16) NeighError!void {
    var req = nl.NetlinkRequest.init(msg_type, flags);

    var family = neigh.family;
    if (family == 0) {
        family = nl.getIPFamily(neigh.ip);
    }

    var msg = nl.NdMsg{
        .family = family,
        .ifindex = neigh.link_index,
        .state = neigh.state,
        .type_ = neigh.type_,
        .flags = neigh.flags,
    };
    req.addData(std.mem.asBytes(&msg));

    // NDA_DST
    const ip_bytes = neigh.ip.toBytes();
    var dst_attr = nl.RtAttr.init(std.heap.page_allocator, nl.NDA_DST, ip_bytes);
    defer dst_attr.deinit();
    req.addRtAttr(&dst_attr);

    // NDA_LLADDR
    if (neigh.hardware_addr) |hw| {
        var hw_attr = nl.RtAttr.init(std.heap.page_allocator, nl.NDA_LLADDR, &hw);
        defer hw_attr.deinit();
        req.addRtAttr(&hw_attr);
    }

    // NDA_FLAGS_EXT
    if (neigh.flags_ext != 0) {
        const val = nl.uint32Attr(neigh.flags_ext);
        var ext_attr = nl.RtAttr.init(std.heap.page_allocator, nl.NDA_FLAGS_EXT, &val);
        defer ext_attr.deinit();
        req.addRtAttr(&ext_attr);
    }

    // NDA_VLAN
    if (neigh.vlan != 0) {
        const val = nl.uint16Attr(neigh.vlan);
        var vlan_attr = nl.RtAttr.init(std.heap.page_allocator, nl.NDA_VLAN, &val);
        defer vlan_attr.deinit();
        req.addRtAttr(&vlan_attr);
    }

    // NDA_VNI
    if (neigh.vni != 0) {
        const val = nl.uint32Attr(neigh.vni);
        var vni_attr = nl.RtAttr.init(std.heap.page_allocator, nl.NDA_VNI, &val);
        defer vni_attr.deinit();
        req.addRtAttr(&vni_attr);
    }

    // NDA_MASTER
    if (neigh.master_index != 0) {
        const val = nl.uint32Attr(@bitCast(neigh.master_index));
        var master_attr = nl.RtAttr.init(std.heap.page_allocator, nl.NDA_MASTER, &val);
        defer master_attr.deinit();
        req.addRtAttr(&master_attr);
    }

    const result = req.executeAlloc(sock, std.heap.page_allocator) catch return error.NetlinkError;
    for (result) |item| std.heap.page_allocator.free(item);
    std.heap.page_allocator.free(result);
}

// neighList gets a list of neighbor entries.
// Equivalent to: `ip neigh show`
pub fn neighList(sock: *nl.NetlinkSocket, link_index: i32, family: u8, allocator: std.mem.Allocator) ![]types.Neigh {
    var req = nl.NetlinkRequest.init(nl.RTM_GETNEIGH, nl.NLM_F_DUMP);

    var msg = nl.NdMsg{
        .family = family,
    };
    req.addData(std.mem.asBytes(&msg));

    const msgs = try req.executeAlloc(sock, allocator);
    defer {
        for (msgs) |item| allocator.free(item);
        allocator.free(msgs);
    }

    var neighs: std.ArrayList(types.Neigh) = .empty;
    errdefer neighs.deinit(allocator);

    for (msgs) |data| {
        if (data.len < @sizeOf(nl.NdMsg)) continue;
        const entry = parseNeighMsg(data);

        if (link_index != 0 and entry.link_index != link_index) continue;

        try neighs.append(allocator, entry);
    }

    return try neighs.toOwnedSlice(allocator);
}

fn parseNeighMsg(data: []const u8) types.Neigh {
    var msg_buf: nl.NdMsg = undefined;
    @memcpy(std.mem.asBytes(&msg_buf), data[0..@sizeOf(nl.NdMsg)]);
    const msg = &msg_buf;

    var neigh = types.Neigh{
        .ip = .{ .v4 = .{ 0, 0, 0, 0 } },
        .family = msg.family,
        .link_index = msg.ifindex,
        .state = msg.state,
        .type_ = msg.type_,
        .flags = msg.flags,
    };

    const attr_data = data[@sizeOf(nl.NdMsg)..];
    var iter = nl.parseAttrs(attr_data);

    while (iter.next()) |attr| {
        switch (attr.type_) {
            nl.NDA_DST => {
                neigh.ip = nl.Address.fromSlice(attr.data) catch continue;
            },
            nl.NDA_LLADDR => {
                if (attr.data.len == 6) {
                    neigh.hardware_addr = attr.data[0..6].*;
                }
            },
            nl.NDA_VLAN => {
                if (attr.data.len >= 2) neigh.vlan = nl.readUint16(attr.data);
            },
            nl.NDA_VNI => {
                if (attr.data.len >= 4) neigh.vni = nl.readUint32(attr.data);
            },
            nl.NDA_MASTER => {
                if (attr.data.len >= 4) neigh.master_index = nl.readInt32(attr.data);
            },
            nl.NDA_FLAGS_EXT => {
                if (attr.data.len >= 4) neigh.flags_ext = nl.readUint32(attr.data);
            },
            else => {},
        }
    }

    return neigh;
}
