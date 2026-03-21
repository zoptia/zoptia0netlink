// list_interfaces.zig - List all network interfaces
//
// This example lists all network interfaces on the system, displaying
// their name, index, MTU, MAC address, and operational state.
//
// Equivalent command:
//   ip link show
//
// Requires root privileges to open a netlink socket.

const std = @import("std");
const netlink = @import("netlink");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Open a netlink socket for route operations
    var sock = netlink.NetlinkSocket.open(0) catch |err| {
        std.debug.print("Failed to open netlink socket: {}\n", .{err});
        std.debug.print("This program requires root privileges.\n", .{});
        return err;
    };
    defer sock.close();

    // Retrieve all links (equivalent to: ip link show)
    const links = netlink.linkList(&sock, allocator) catch |err| {
        std.debug.print("Failed to list links: {}\n", .{err});
        return err;
    };
    defer allocator.free(links);

    std.debug.print("{d} interface(s) found:\n", .{links.len});
    std.debug.print("{s:<6} {s:<16} {s:<8} {s:<20} {s:<12} {s:<10}\n", .{
        "Index", "Name", "MTU", "MAC Address", "State", "Type",
    });
    std.debug.print("{s}\n", .{"-" ** 72});

    for (links) |link| {
        const name = link.getName();
        const state = link.oper_state.toString();
        const link_type = link.link_type.toString();

        // Format MAC address
        var mac_buf: [18]u8 = undefined;
        var mac_str: []const u8 = "none";
        if (link.hardware_addr) |hw| {
            const written = std.fmt.bufPrint(&mac_buf, "{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}", .{
                hw[0], hw[1], hw[2], hw[3], hw[4], hw[5],
            }) catch "??:??:??:??:??:??";
            mac_str = written;
        }

        std.debug.print("{d:<6} {s:<16} {d:<8} {s:<20} {s:<12} {s:<10}\n", .{
            link.index,
            name,
            link.mtu,
            mac_str,
            state,
            link_type,
        });

        // Show flags if the interface is up
        if (link.flags & 0x1 != 0) {
            std.debug.print("       flags: UP", .{});
            if (link.flags & 0x2 != 0) std.debug.print(",BROADCAST", .{});
            if (link.flags & 0x8 != 0) std.debug.print(",LOOPBACK", .{});
            if (link.flags & 0x1000 != 0) std.debug.print(",MULTICAST", .{});
            if (link.flags & 0x100 != 0) std.debug.print(",PROMISC", .{});
            std.debug.print("\n", .{});
        }

        // Show statistics if available
        if (link.statistics) |stats| {
            std.debug.print("       RX: {d} packets, {d} bytes, {d} errors, {d} dropped\n", .{
                stats.rx_packets, stats.rx_bytes, stats.rx_errors, stats.rx_dropped,
            });
            std.debug.print("       TX: {d} packets, {d} bytes, {d} errors, {d} dropped\n", .{
                stats.tx_packets, stats.tx_bytes, stats.tx_errors, stats.tx_dropped,
            });
        }
    }
}
