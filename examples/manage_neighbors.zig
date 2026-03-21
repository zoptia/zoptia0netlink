// manage_neighbors.zig - Add, list, and remove ARP/neighbor entries
//
// This example demonstrates neighbor (ARP) table management:
//   1. Creates a dummy interface for testing
//   2. Adds a static ARP entry
//   3. Lists all neighbor entries
//   4. Deletes the entry
//   5. Cleans up the interface
//
// Equivalent commands:
//   ip link add dummy3 type dummy
//   ip link set dummy3 up
//   ip addr add 10.200.0.1/24 dev dummy3
//   ip neigh add 10.200.0.50 lladdr aa:bb:cc:dd:ee:ff dev dummy3 nud permanent
//   ip neigh show dev dummy3
//   ip neigh del 10.200.0.50 dev dummy3
//   ip link del dummy3
//
// Requires root privileges.

const std = @import("std");
const netlink = @import("netlink");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var sock = netlink.NetlinkSocket.open(0) catch |err| {
        std.debug.print("Failed to open netlink socket: {}\n", .{err});
        std.debug.print("This program requires root privileges.\n", .{});
        return err;
    };
    defer sock.close();

    // Step 1: Create a dummy interface (ip link add dummy3 type dummy)
    std.debug.print("Creating dummy interface 'dummy3'...\n", .{});
    var dummy_attrs = netlink.LinkAttrs{};
    dummy_attrs.setName("dummy3");
    dummy_attrs.link_type = .dummy;

    netlink.linkAdd(&sock, &dummy_attrs) catch |err| {
        std.debug.print("Failed to create dummy3: {}\n", .{err});
        return err;
    };

    const dummy = netlink.linkByName(&sock, "dummy3") catch |err| {
        std.debug.print("Failed to find dummy3: {}\n", .{err});
        return err;
    };
    const link_index = dummy.index;
    std.debug.print("Created 'dummy3' with index {d}.\n", .{link_index});

    // Bring the interface up and assign an address
    // (ip link set dummy3 up && ip addr add 10.200.0.1/24 dev dummy3)
    netlink.linkSetUp(&sock, link_index) catch |err| {
        std.debug.print("Failed to bring dummy3 up: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };

    const local_net = netlink.parseIPNet("10.200.0.1/24") catch unreachable;
    var local_addr = netlink.Addr{
        .ip = local_net.ip,
        .prefix_len = local_net.prefix_len,
        .link_index = link_index,
    };
    netlink.addrAdd(&sock, link_index, &local_addr) catch |err| {
        std.debug.print("Failed to add address to dummy3: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };
    std.debug.print("Assigned 10.200.0.1/24 to dummy3.\n", .{});

    // Step 2: Add a static ARP entry
    // (ip neigh add 10.200.0.50 lladdr aa:bb:cc:dd:ee:ff dev dummy3 nud permanent)
    std.debug.print("\nAdding static neighbor 10.200.0.50 -> aa:bb:cc:dd:ee:ff...\n", .{});
    const neigh_ip = netlink.parseIP("10.200.0.50") catch unreachable;

    const neigh_entry = netlink.Neigh{
        .link_index = link_index,
        .ip = neigh_ip,
        .hardware_addr = .{ 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff },
        .state = 0x80, // NUD_PERMANENT
    };

    netlink.neighAdd(&sock, &neigh_entry) catch |err| {
        std.debug.print("Failed to add neighbor: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };
    std.debug.print("Neighbor entry added.\n", .{});

    // Step 3: List neighbor entries on this interface (ip neigh show dev dummy3)
    std.debug.print("\nNeighbor table for dummy3:\n", .{});
    listNeighbors(&sock, link_index, allocator);

    // Step 4: Delete the neighbor entry (ip neigh del 10.200.0.50 dev dummy3)
    std.debug.print("\nDeleting neighbor 10.200.0.50...\n", .{});
    netlink.neighDel(&sock, &neigh_entry) catch |err| {
        std.debug.print("Failed to delete neighbor: {}\n", .{err});
    };
    std.debug.print("Neighbor entry deleted.\n", .{});

    // Verify deletion
    std.debug.print("\nNeighbor table after deletion:\n", .{});
    listNeighbors(&sock, link_index, allocator);

    // Step 5: Cleanup (ip link del dummy3)
    std.debug.print("\nCleaning up...\n", .{});
    netlink.linkDel(&sock, link_index) catch |err| {
        std.debug.print("Warning: failed to delete dummy3: {}\n", .{err});
    };
    std.debug.print("Deleted 'dummy3'.\n", .{});
    std.debug.print("Done.\n", .{});
}

fn listNeighbors(sock: *netlink.NetlinkSocket, link_index: i32, allocator: std.mem.Allocator) void {
    // List all neighbor families on this interface (family = 0 for all)
    const neighs = netlink.neighList(sock, link_index, 0, allocator) catch |err| {
        std.debug.print("  Failed to list neighbors: {}\n", .{err});
        return;
    };
    defer allocator.free(neighs);

    if (neighs.len == 0) {
        std.debug.print("  (no neighbor entries)\n", .{});
        return;
    }

    const writer = std.io.getStdErr().writer();

    for (neighs) |neigh| {
        std.debug.print("  ", .{});

        // IP address
        neigh.ip.format(writer) catch {};

        // MAC address
        if (neigh.hardware_addr) |hw| {
            std.debug.print(" lladdr {x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}", .{
                hw[0], hw[1], hw[2], hw[3], hw[4], hw[5],
            });
        }

        // State description
        const state_str = neighborStateString(neigh.state);
        std.debug.print(" {s}", .{state_str});

        std.debug.print("\n", .{});
    }
}

fn neighborStateString(state: u16) []const u8 {
    if (state & 0x80 != 0) return "PERMANENT";
    if (state & 0x40 != 0) return "NOARP";
    if (state & 0x02 != 0) return "REACHABLE";
    if (state & 0x04 != 0) return "STALE";
    if (state & 0x08 != 0) return "DELAY";
    if (state & 0x10 != 0) return "PROBE";
    if (state & 0x20 != 0) return "FAILED";
    if (state & 0x01 != 0) return "INCOMPLETE";
    return "NONE";
}
