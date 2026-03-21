const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const mem = std.mem;
const native_endian = @import("builtin").cpu.arch.endian();

pub const FAMILY_ALL: u8 = linux.AF.UNSPEC;
pub const FAMILY_V4: u8 = linux.AF.INET;
pub const FAMILY_V6: u8 = linux.AF.INET6;
pub const FAMILY_MPLS: u8 = 28; // AF_MPLS

pub const RECEIVE_BUFFER_SIZE: usize = 65536;
pub const PID_KERNEL: u32 = 0;

pub const NETLINK_ROUTE: u32 = 0;
pub const NETLINK_XFRM: u32 = 6;
pub const NETLINK_NETFILTER: u32 = 12;
pub const NETLINK_GET_STRICT_CHK: u32 = 12;
pub const SOL_NETLINK: u32 = 270;

pub const NLM_F_REQUEST: u16 = 0x0001;
pub const NLM_F_MULTI: u16 = 0x0002;
pub const NLM_F_ACK: u16 = 0x0004;
pub const NLM_F_DUMP_INTR: u16 = 0x0010;
pub const NLM_F_ROOT: u16 = 0x0100;
pub const NLM_F_MATCH: u16 = 0x0200;
pub const NLM_F_DUMP: u16 = NLM_F_ROOT | NLM_F_MATCH;
pub const NLM_F_CREATE: u16 = 0x0400;
pub const NLM_F_EXCL: u16 = 0x0200;
pub const NLM_F_REPLACE: u16 = 0x0100;
pub const NLM_F_APPEND: u16 = 0x0800;
pub const NLM_F_CAPPED: u16 = 0x0100;
pub const NLM_F_ACK_TLVS: u16 = 0x0200;

pub const NLMSG_NOOP: u16 = 0x1;
pub const NLMSG_ERROR: u16 = 0x2;
pub const NLMSG_DONE: u16 = 0x3;
pub const NLMSG_OVERRUN: u16 = 0x4;

pub const NLMSG_ALIGNTO: u32 = 4;
pub const NLMSG_HDRLEN: u32 = nlmsgAlign(@sizeOf(NlMsgHdr));

pub const RTA_ALIGNTO: u32 = 4;

// RTM message types
pub const RTM_NEWLINK: u16 = 16;
pub const RTM_DELLINK: u16 = 17;
pub const RTM_GETLINK: u16 = 18;
pub const RTM_SETLINK: u16 = 19;
pub const RTM_NEWADDR: u16 = 20;
pub const RTM_DELADDR: u16 = 21;
pub const RTM_GETADDR: u16 = 22;
pub const RTM_NEWROUTE: u16 = 24;
pub const RTM_DELROUTE: u16 = 25;
pub const RTM_GETROUTE: u16 = 26;
pub const RTM_NEWNEIGH: u16 = 28;
pub const RTM_DELNEIGH: u16 = 29;
pub const RTM_GETNEIGH: u16 = 30;
pub const RTM_NEWRULE: u16 = 32;
pub const RTM_DELRULE: u16 = 33;
pub const RTM_GETRULE: u16 = 34;
pub const RTM_NEWQDISC: u16 = 36;
pub const RTM_DELQDISC: u16 = 37;
pub const RTM_GETQDISC: u16 = 38;

// IFLA attribute types
pub const IFLA_UNSPEC: u16 = 0;
pub const IFLA_ADDRESS: u16 = 1;
pub const IFLA_BROADCAST: u16 = 2;
pub const IFLA_IFNAME: u16 = 3;
pub const IFLA_MTU: u16 = 4;
pub const IFLA_LINK: u16 = 5;
pub const IFLA_QDISC: u16 = 6;
pub const IFLA_STATS: u16 = 7;
pub const IFLA_COST: u16 = 8;
pub const IFLA_PRIORITY: u16 = 9;
pub const IFLA_MASTER: u16 = 10;
pub const IFLA_WIRELESS: u16 = 11;
pub const IFLA_PROTINFO: u16 = 12;
pub const IFLA_TXQLEN: u16 = 13;
pub const IFLA_MAP: u16 = 14;
pub const IFLA_WEIGHT: u16 = 15;
pub const IFLA_OPERSTATE: u16 = 16;
pub const IFLA_LINKMODE: u16 = 17;
pub const IFLA_LINKINFO: u16 = 18;
pub const IFLA_NET_NS_PID: u16 = 19;
pub const IFLA_IFALIAS: u16 = 20;
pub const IFLA_NUM_VF: u16 = 21;
pub const IFLA_VFINFO_LIST: u16 = 22;
pub const IFLA_STATS64: u16 = 23;
pub const IFLA_VF_PORTS: u16 = 24;
pub const IFLA_PORT_SELF: u16 = 25;
pub const IFLA_AF_SPEC: u16 = 26;
pub const IFLA_GROUP: u16 = 27;
pub const IFLA_NET_NS_FD: u16 = 28;
pub const IFLA_EXT_MASK: u16 = 29;
pub const IFLA_PROMISCUITY: u16 = 30;
pub const IFLA_NUM_TX_QUEUES: u16 = 31;
pub const IFLA_NUM_RX_QUEUES: u16 = 32;
pub const IFLA_CARRIER: u16 = 33;
pub const IFLA_PHYS_PORT_ID: u16 = 34;
pub const IFLA_CARRIER_CHANGES: u16 = 35;
pub const IFLA_PHYS_SWITCH_ID: u16 = 36;
pub const IFLA_LINK_NETNSID: u16 = 37;
pub const IFLA_PHYS_PORT_NAME: u16 = 38;
pub const IFLA_PROTO_DOWN: u16 = 39;
pub const IFLA_GSO_MAX_SEGS: u16 = 40;
pub const IFLA_GSO_MAX_SIZE: u16 = 41;
pub const IFLA_PAD: u16 = 42;
pub const IFLA_XDP: u16 = 43;
pub const IFLA_EVENT: u16 = 44;
pub const IFLA_NEW_NETNSID: u16 = 45;
pub const IFLA_IF_NETNSID: u16 = 46;
pub const IFLA_PERM_ADDRESS: u16 = 54;
pub const IFLA_PARENT_DEV_NAME: u16 = 56;
pub const IFLA_PARENT_DEV_BUS_NAME: u16 = 57;
pub const IFLA_GRO_MAX_SIZE: u16 = 58;
pub const IFLA_TSO_MAX_SIZE: u16 = 59;
pub const IFLA_TSO_MAX_SEGS: u16 = 60;
pub const IFLA_ALLMULTI: u16 = 61;
pub const IFLA_GSO_IPV4_MAX_SIZE: u16 = 63;
pub const IFLA_GRO_IPV4_MAX_SIZE: u16 = 64;
pub const IFLA_ALT_IFNAME: u16 = 53;

// IFLA_INFO attribute types
pub const IFLA_INFO_UNSPEC: u16 = 0;
pub const IFLA_INFO_KIND: u16 = 1;
pub const IFLA_INFO_DATA: u16 = 2;
pub const IFLA_INFO_XSTATS: u16 = 3;
pub const IFLA_INFO_SLAVE_KIND: u16 = 4;
pub const IFLA_INFO_SLAVE_DATA: u16 = 5;

// IFA attribute types
pub const IFA_UNSPEC: u16 = 0;
pub const IFA_ADDRESS: u16 = 1;
pub const IFA_LOCAL: u16 = 2;
pub const IFA_LABEL: u16 = 3;
pub const IFA_BROADCAST: u16 = 4;
pub const IFA_ANYCAST: u16 = 5;
pub const IFA_CACHEINFO: u16 = 6;
pub const IFA_MULTICAST: u16 = 7;
pub const IFA_FLAGS: u16 = 8;
pub const IFA_PROTO: u16 = 11;

// RTA attribute types
pub const RTA_UNSPEC: u16 = 0;
pub const RTA_DST: u16 = 1;
pub const RTA_SRC: u16 = 2;
pub const RTA_IIF: u16 = 3;
pub const RTA_OIF: u16 = 4;
pub const RTA_GATEWAY: u16 = 5;
pub const RTA_PRIORITY: u16 = 6;
pub const RTA_PREFSRC: u16 = 7;
pub const RTA_METRICS: u16 = 8;
pub const RTA_MULTIPATH: u16 = 9;
pub const RTA_PROTOINFO: u16 = 10;
pub const RTA_FLOW: u16 = 11;
pub const RTA_CACHEINFO: u16 = 12;
pub const RTA_SESSION: u16 = 13;
pub const RTA_TABLE: u16 = 15;
pub const RTA_OIF_NH: u16 = 4;
pub const RTA_ENCAP_TYPE: u16 = 21;
pub const RTA_ENCAP: u16 = 22;
pub const RTA_NH_ID: u16 = 30;

// NDA attribute types
pub const NDA_UNSPEC: u16 = 0;
pub const NDA_DST: u16 = 1;
pub const NDA_LLADDR: u16 = 2;
pub const NDA_CACHEINFO: u16 = 3;
pub const NDA_PROBES: u16 = 4;
pub const NDA_VLAN: u16 = 5;
pub const NDA_PORT: u16 = 6;
pub const NDA_VNI: u16 = 7;
pub const NDA_IFINDEX: u16 = 8;
pub const NDA_MASTER: u16 = 9;
pub const NDA_FLAGS_EXT: u16 = 15;

// Neighbor states
pub const NUD_NONE: u16 = 0x00;
pub const NUD_INCOMPLETE: u16 = 0x01;
pub const NUD_REACHABLE: u16 = 0x02;
pub const NUD_STALE: u16 = 0x04;
pub const NUD_DELAY: u16 = 0x08;
pub const NUD_PROBE: u16 = 0x10;
pub const NUD_FAILED: u16 = 0x20;
pub const NUD_NOARP: u16 = 0x40;
pub const NUD_PERMANENT: u16 = 0x80;

// Neighbor flags
pub const NTF_USE: u8 = 0x01;
pub const NTF_SELF: u8 = 0x02;
pub const NTF_MASTER: u8 = 0x04;
pub const NTF_PROXY: u8 = 0x08;

// IFF flags
pub const IFF_UP: u32 = 0x1;
pub const IFF_BROADCAST: u32 = 0x2;
pub const IFF_LOOPBACK: u32 = 0x8;
pub const IFF_POINTOPOINT: u32 = 0x10;
pub const IFF_MULTICAST: u32 = 0x1000;
pub const IFF_NOARP: u32 = 0x80;
pub const IFF_PROMISC: u32 = 0x100;
pub const IFF_ALLMULTI: u32 = 0x200;

// Route protocol values
pub const RTPROT_UNSPEC: u8 = 0;
pub const RTPROT_REDIRECT: u8 = 1;
pub const RTPROT_KERNEL: u8 = 2;
pub const RTPROT_BOOT: u8 = 3;
pub const RTPROT_STATIC: u8 = 4;

// Route scope
pub const RT_SCOPE_UNIVERSE: u8 = 0;
pub const RT_SCOPE_SITE: u8 = 200;
pub const RT_SCOPE_LINK: u8 = 253;
pub const RT_SCOPE_HOST: u8 = 254;
pub const RT_SCOPE_NOWHERE: u8 = 255;

// Route types
pub const RTN_UNSPEC: u8 = 0;
pub const RTN_UNICAST: u8 = 1;
pub const RTN_LOCAL: u8 = 2;
pub const RTN_BROADCAST: u8 = 3;
pub const RTN_UNREACHABLE: u8 = 7;

// Route table
pub const RT_TABLE_UNSPEC: u8 = 0;
pub const RT_TABLE_MAIN: u8 = 254;
pub const RT_TABLE_LOCAL: u8 = 255;

// ARPHRD types
pub const ARPHRD_ETHER: u16 = 1;
pub const ARPHRD_LOOPBACK: u16 = 772;
pub const ARPHRD_NONE: u16 = 0xFFFE;

// NLA flags
pub const NLA_F_NESTED: u16 = 1 << 15;
pub const NLA_F_NET_BYTEORDER: u16 = 1 << 14;

// NLMSGERR attribute types
pub const NLMSGERR_ATTR_UNUSED: u16 = 0;
pub const NLMSGERR_ATTR_MSG: u16 = 1;
pub const NLMSGERR_ATTR_OFFS: u16 = 2;
pub const NLMSGERR_ATTR_COOKIE: u16 = 3;

pub const NlMsgHdr = extern struct {
    len: u32,
    type_: u16,
    flags: u16,
    seq: u32,
    pid: u32,
};

pub const IfInfoMsg = extern struct {
    family: u8,
    _pad: u8 = 0,
    type_: u16 = 0,
    index: i32 = 0,
    flags: u32 = 0,
    change: u32 = 0,
};

pub const IfAddrMsg = extern struct {
    family: u8,
    prefixlen: u8 = 0,
    flags: u8 = 0,
    scope: u8 = 0,
    index: u32 = 0,
};

pub const RtMsg = extern struct {
    family: u8 = 0,
    dst_len: u8 = 0,
    src_len: u8 = 0,
    tos: u8 = 0,
    table: u8 = 0,
    protocol: u8 = 0,
    scope: u8 = 0,
    type_: u8 = 0,
    flags: u32 = 0,
};

pub const NdMsg = extern struct {
    family: u8 = 0,
    pad1: u8 = 0,
    pad2: u16 = 0,
    ifindex: i32 = 0,
    state: u16 = 0,
    flags: u8 = 0,
    type_: u8 = 0,
};

pub const RtAttrHdr = extern struct {
    len: u16,
    type_: u16,
};

pub const IfaCacheInfo = extern struct {
    prefered: u32 = 0,
    valid: u32 = 0,
    cstamp: u32 = 0,
    tstamp: u32 = 0,
};

pub fn nlmsgAlign(len: anytype) u32 {
    const l: u32 = @intCast(len);
    return (l + NLMSG_ALIGNTO - 1) & ~(NLMSG_ALIGNTO - 1);
}

pub fn rtaAlign(len: anytype) u32 {
    const l: u32 = @intCast(len);
    return (l + RTA_ALIGNTO - 1) & ~(RTA_ALIGNTO - 1);
}

pub fn getIPFamily(addr: Address) u8 {
    return switch (addr) {
        .v4 => FAMILY_V4,
        .v6 => FAMILY_V6,
    };
}

pub const Address = union(enum) {
    v4: [4]u8,
    v6: [16]u8,

    pub fn toBytes(self: *const Address) []const u8 {
        return switch (self.*) {
            .v4 => &self.v4,
            .v6 => &self.v6,
        };
    }

    pub fn fromSlice(data: []const u8) !Address {
        if (data.len == 4) {
            return .{ .v4 = data[0..4].* };
        } else if (data.len == 16) {
            return .{ .v6 = data[0..16].* };
        }
        return error.InvalidAddressLength;
    }

    pub fn eql(self: Address, other: Address) bool {
        return switch (self) {
            .v4 => |a| switch (other) {
                .v4 => |b| std.mem.eql(u8, &a, &b),
                .v6 => false,
            },
            .v6 => |a| switch (other) {
                .v4 => false,
                .v6 => |b| std.mem.eql(u8, &a, &b),
            },
        };
    }

    pub fn format(self: Address, writer: anytype) !void {
        switch (self) {
            .v4 => |a| try writer.print("{d}.{d}.{d}.{d}", .{ a[0], a[1], a[2], a[3] }),
            .v6 => |a| {
                var i: usize = 0;
                while (i < 16) : (i += 2) {
                    if (i > 0) try writer.writeAll(":");
                    const val = (@as(u16, a[i]) << 8) | @as(u16, a[i + 1]);
                    try writer.print("{x}", .{val});
                }
            },
        }
    }

    pub fn isZero(self: *const Address) bool {
        const bytes = self.toBytes();
        for (bytes) |b| {
            if (b != 0) return false;
        }
        return true;
    }
};

pub const NetlinkSocket = struct {
    fd: posix.fd_t,
    sa: linux.sockaddr.nl,
    seq: u32 = 0,

    pub fn open(protocol: u32) !NetlinkSocket {
        const fd = try posix.socket(
            linux.AF.NETLINK,
            linux.SOCK.RAW | linux.SOCK.CLOEXEC,
            protocol,
        );
        errdefer posix.close(fd);

        var sa = linux.sockaddr.nl{
            .pid = 0,
            .groups = 0,
        };

        try posix.bind(fd, @ptrCast(&sa), @sizeOf(linux.sockaddr.nl));

        // read back the assigned port id
        var bound_sa: linux.sockaddr.nl = undefined;
        var sa_len: u32 = @sizeOf(linux.sockaddr.nl);
        const rc = linux.getsockname(fd, @ptrCast(&bound_sa), &sa_len);
        if (rc != 0) return error.GetSockNameFailed;
        sa.pid = bound_sa.pid;

        return .{
            .fd = fd,
            .sa = sa,
        };
    }

    pub fn close(self: *NetlinkSocket) void {
        posix.close(self.fd);
        self.fd = -1;
    }

    pub fn send(self: *NetlinkSocket, data: []const u8) !void {
        var dest_sa = linux.sockaddr.nl{
            .pid = 0,
            .groups = 0,
        };
        const rc = linux.sendto(
            self.fd,
            data.ptr,
            data.len,
            0,
            @ptrCast(&dest_sa),
            @sizeOf(linux.sockaddr.nl),
        );
        if (rc < 0) return error.SendFailed;
    }

    pub fn receive(self: *NetlinkSocket, buf: []u8) !struct { len: usize, pid: u32 } {
        var from_sa: linux.sockaddr.nl = undefined;
        var from_len: u32 = @sizeOf(linux.sockaddr.nl);
        const rc = linux.recvfrom(
            self.fd,
            buf.ptr,
            buf.len,
            0,
            @ptrCast(&from_sa),
            &from_len,
        );
        const n: usize = @intCast(rc);
        if (n < @sizeOf(NlMsgHdr)) return error.ShortRead;
        return .{ .len = n, .pid = from_sa.pid };
    }

    pub fn getNextSeq(self: *NetlinkSocket) u32 {
        self.seq += 1;
        return self.seq;
    }
};

pub const RtAttr = struct {
    type_: u16,
    data: ?[]const u8 = null,
    children: std.ArrayList(RtAttr),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, attr_type: u16, data: ?[]const u8) RtAttr {
        return .{
            .type_ = attr_type,
            .data = data,
            .children = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RtAttr) void {
        for (self.children.items) |*child| {
            child.deinit();
        }
        self.children.deinit(self.allocator);
    }

    pub fn addChild(self: *RtAttr, attr_type: u16, data: ?[]const u8) !*RtAttr {
        try self.children.append(self.allocator, RtAttr.init(self.allocator, attr_type, data));
        return &self.children.items[self.children.items.len - 1];
    }

    pub fn serializedLen(self: *const RtAttr) u32 {
        const data_len: u32 = if (self.data) |d| @as(u32, @intCast(d.len)) else 0;
        if (self.children.items.len == 0) {
            return @sizeOf(RtAttrHdr) + data_len;
        }
        var l: u32 = 0;
        for (self.children.items) |*child| {
            l += rtaAlign(child.serializedLen());
        }
        l += @sizeOf(RtAttrHdr);
        return rtaAlign(l + data_len);
    }

    pub fn serialize(self: *const RtAttr, buf: []u8) u32 {
        const length = self.serializedLen();
        const aligned = rtaAlign(length);
        if (buf.len < aligned) return 0;

        @memset(buf[0..aligned], 0);

        var next: u32 = @sizeOf(RtAttrHdr);
        if (self.data) |d| {
            @memcpy(buf[next..][0..d.len], d);
            next += rtaAlign(@as(u32, @intCast(d.len)));
        }

        for (self.children.items) |*child| {
            const child_len = child.serialize(buf[next..]);
            next += rtaAlign(child_len);
        }

        // write header
        std.mem.writeInt(u16, buf[0..2], @intCast(length), native_endian);
        std.mem.writeInt(u16, buf[2..4], self.type_, native_endian);

        return length;
    }
};

pub const NetlinkRequest = struct {
    hdr: NlMsgHdr,
    data_buf: [4096]u8 = undefined,
    data_len: u32 = 0,

    pub fn init(msg_type: u16, flags: u16) NetlinkRequest {
        return .{
            .hdr = .{
                .len = @sizeOf(NlMsgHdr),
                .type_ = msg_type,
                .flags = NLM_F_REQUEST | flags,
                .seq = 0,
                .pid = 0,
            },
        };
    }

    pub fn addData(self: *NetlinkRequest, data: []const u8) void {
        @memcpy(self.data_buf[self.data_len..][0..data.len], data);
        self.data_len += @intCast(data.len);
    }

    pub fn addRtAttr(self: *NetlinkRequest, attr: *const RtAttr) void {
        const len = attr.serialize(self.data_buf[self.data_len..]);
        self.data_len += rtaAlign(len);
    }

    pub fn serialize(self: *NetlinkRequest, buf: []u8) u32 {
        const total: u32 = @sizeOf(NlMsgHdr) + self.data_len;
        self.hdr.len = total;

        const hdr_bytes: [*]const u8 = @ptrCast(&self.hdr);
        @memcpy(buf[0..@sizeOf(NlMsgHdr)], hdr_bytes[0..@sizeOf(NlMsgHdr)]);
        if (self.data_len > 0) {
            @memcpy(buf[@sizeOf(NlMsgHdr)..][0..self.data_len], self.data_buf[0..self.data_len]);
        }
        return total;
    }

    pub fn execute(self: *NetlinkRequest, sock: *NetlinkSocket) ![][]u8 {
        return self.executeAlloc(sock, std.heap.page_allocator);
    }

    pub fn executeAlloc(self: *NetlinkRequest, sock: *NetlinkSocket, allocator: std.mem.Allocator) ![][]u8 {
        self.hdr.seq = sock.getNextSeq();
        self.hdr.pid = sock.sa.pid;

        var send_buf: [8192]u8 = undefined;
        const total = self.serialize(&send_buf);
        try sock.send(send_buf[0..total]);

        var results: std.ArrayList([]u8) = .{};
        errdefer {
            for (results.items) |item| allocator.free(item);
            results.deinit(allocator);
        }

        var recv_buf: [RECEIVE_BUFFER_SIZE]u8 = undefined;

        while (true) {
            const recv = try sock.receive(&recv_buf);
            if (recv.pid != PID_KERNEL) return error.WrongSenderPid;

            var offset: usize = 0;
            while (offset + @sizeOf(NlMsgHdr) <= recv.len) {
                const hdr: *const NlMsgHdr = @alignCast(@ptrCast(&recv_buf[offset]));

                if (hdr.seq != self.hdr.seq) {
                    offset += nlmsgAlign(hdr.len);
                    continue;
                }

                if (hdr.type_ == NLMSG_DONE) return try results.toOwnedSlice(allocator);

                if (hdr.type_ == NLMSG_ERROR) {
                    if (hdr.len < @sizeOf(NlMsgHdr) + 4) return error.InvalidMessage;
                    const err_bytes = recv_buf[offset + @sizeOf(NlMsgHdr) ..][0..4];
                    const errno: i32 = @bitCast(std.mem.readInt(u32, err_bytes, native_endian));
                    if (errno == 0) return try results.toOwnedSlice(allocator);
                    return error.NetlinkError;
                }

                const payload_start = offset + @sizeOf(NlMsgHdr);
                const payload_end = offset + hdr.len;
                if (payload_end <= recv.len and payload_start < payload_end) {
                    const data = try allocator.dupe(u8, recv_buf[payload_start..payload_end]);
                    try results.append(allocator, data);
                }

                if (hdr.flags & NLM_F_MULTI == 0) return try results.toOwnedSlice(allocator);

                offset += nlmsgAlign(hdr.len);
            }
        }
    }
};

pub fn parseAttrs(data: []const u8) AttrIterator {
    return .{ .data = data, .offset = 0 };
}

pub const ParsedAttr = struct {
    type_: u16,
    data: []const u8,
};

pub const AttrIterator = struct {
    data: []const u8,
    offset: usize,

    pub fn next(self: *AttrIterator) ?ParsedAttr {
        if (self.offset + @sizeOf(RtAttrHdr) > self.data.len) return null;

        const len = std.mem.readInt(u16, self.data[self.offset..][0..2], native_endian);
        const attr_type = std.mem.readInt(u16, self.data[self.offset + 2 ..][0..2], native_endian);

        if (len < @sizeOf(RtAttrHdr) or self.offset + len > self.data.len) return null;

        const payload = self.data[self.offset + @sizeOf(RtAttrHdr) .. self.offset + len];
        self.offset += rtaAlign(len);

        return .{
            .type_ = attr_type & ~@as(u16, NLA_F_NESTED | NLA_F_NET_BYTEORDER),
            .data = payload,
        };
    }
};

pub fn uint32Attr(val: u32) [4]u8 {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, val, native_endian);
    return buf;
}

pub fn uint16Attr(val: u16) [2]u8 {
    var buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &buf, val, native_endian);
    return buf;
}

pub fn uint8Attr(val: u8) [1]u8 {
    return .{val};
}

pub fn readUint32(data: []const u8) u32 {
    return std.mem.readInt(u32, data[0..4], native_endian);
}

pub fn readUint16(data: []const u8) u16 {
    return std.mem.readInt(u16, data[0..2], native_endian);
}

pub fn readInt32(data: []const u8) i32 {
    return @bitCast(readUint32(data));
}

pub fn zeroTerminated(s: []const u8) []const u8 {
    // caller ensures the buffer has a trailing zero
    return s;
}

pub fn asBytes(comptime T: type, val: *const T) []const u8 {
    return std.mem.asBytes(val);
}

pub fn bytesAsValue(comptime T: type, data: []const u8) T {
    var val: T = undefined;
    @memcpy(std.mem.asBytes(&val), data[0..@sizeOf(T)]);
    return val;
}
