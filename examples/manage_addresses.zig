// manage_addresses.zig - Add, list, and remove IP addresses on interfaces
//
// This example demonstrates managing IP addresses on network interfaces:
//   1. Creates a dummy interface for testing
//   2. Adds an IPv4 address
//   3. Adds an IPv6 address
//   4. Lists all addresses on the interface
//   5. Removes the addresses
//   6. Cleans up the dummy interface
//
// Equivalent commands:
//   ip link add dummy1 type dummy
//   ip link set dummy1 up
//   ip addr add 192.168.100.1/24 dev dummy1
//   ip addr add fd00::1/64 dev dummy1
//   ip addr show dev dummy1
//   ip addr del 192.168.100.1/24 dev dummy1
//   ip addr del fd00::1/64 dev dummy1
//   ip link del dummy1
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

    // Step 1: Create a dummy interface for testing (ip link add dummy1 type dummy)
    std.debug.print("Creating dummy interface 'dummy1'...\n", .{});
    var dummy_attrs = netlink.LinkAttrs{};
    dummy_attrs.setName("dummy1");
    dummy_attrs.link_type = .dummy;

    netlink.linkAdd(&sock, &dummy_attrs) catch |err| {
        std.debug.print("Failed to create dummy1: {}\n", .{err});
        return err;
    };

    const dummy = netlink.linkByName(&sock, "dummy1") catch |err| {
        std.debug.print("Failed to find dummy1: {}\n", .{err});
        return err;
    };
    const link_index = dummy.index;
    std.debug.print("Created 'dummy1' with index {d}.\n", .{link_index});

    // Bring the interface up (ip link set dummy1 up)
    netlink.linkSetUp(&sock, link_index) catch |err| {
        std.debug.print("Failed to bring dummy1 up: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };
    std.debug.print("Interface 'dummy1' is up.\n", .{});

    // Step 2: Add an IPv4 address (ip addr add 192.168.100.1/24 dev dummy1)
    std.debug.print("\nAdding IPv4 address 192.168.100.1/24...\n", .{});
    const ipv4_net = netlink.parseIPNet("192.168.100.1/24") catch |err| {
        std.debug.print("Failed to parse IPv4 CIDR: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };

    var ipv4_addr = netlink.Addr{
        .ip = ipv4_net.ip,
        .prefix_len = ipv4_net.prefix_len,
        .link_index = link_index,
    };

    netlink.addrAdd(&sock, link_index, &ipv4_addr) catch |err| {
        std.debug.print("Failed to add IPv4 address: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };
    std.debug.print("Added 192.168.100.1/24 to dummy1.\n", .{});

    // Step 3: Add an IPv6 address (ip addr add fd00::1/64 dev dummy1)
    std.debug.print("Adding IPv6 address fd00::1/64...\n", .{});
    const ipv6_net = netlink.parseIPNet("fd00::1/64") catch |err| {
        std.debug.print("Failed to parse IPv6 CIDR: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };

    var ipv6_addr = netlink.Addr{
        .ip = ipv6_net.ip,
        .prefix_len = ipv6_net.prefix_len,
        .link_index = link_index,
    };

    netlink.addrAdd(&sock, link_index, &ipv6_addr) catch |err| {
        std.debug.print("Failed to add IPv6 address: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };
    std.debug.print("Added fd00::1/64 to dummy1.\n", .{});

    // Step 4: List addresses on the interface (ip addr show dev dummy1)
    std.debug.print("\nListing addresses on dummy1:\n", .{});
    listAddresses(&sock, link_index, allocator);

    // Step 5: Remove the IPv4 address (ip addr del 192.168.100.1/24 dev dummy1)
    std.debug.print("\nRemoving IPv4 address 192.168.100.1/24...\n", .{});
    netlink.addrDel(&sock, link_index, &ipv4_addr) catch |err| {
        std.debug.print("Failed to remove IPv4 address: {}\n", .{err});
    };
    std.debug.print("Removed 192.168.100.1/24 from dummy1.\n", .{});

    // Remove the IPv6 address (ip addr del fd00::1/64 dev dummy1)
    std.debug.print("Removing IPv6 address fd00::1/64...\n", .{});
    netlink.addrDel(&sock, link_index, &ipv6_addr) catch |err| {
        std.debug.print("Failed to remove IPv6 address: {}\n", .{err});
    };
    std.debug.print("Removed fd00::1/64 from dummy1.\n", .{});

    // Verify addresses are gone
    std.debug.print("\nAddresses after removal:\n", .{});
    listAddresses(&sock, link_index, allocator);

    // Step 6: Cleanup (ip link del dummy1)
    std.debug.print("\nCleaning up...\n", .{});
    netlink.linkDel(&sock, link_index) catch |err| {
        std.debug.print("Warning: failed to delete dummy1: {}\n", .{err});
    };
    std.debug.print("Deleted 'dummy1'.\n", .{});
    std.debug.print("Done.\n", .{});
}

fn listAddresses(sock: *netlink.NetlinkSocket, link_index: i32, allocator: std.mem.Allocator) void {
    // List all address families (AF_UNSPEC = 0)
    const addrs = netlink.addrList(sock, link_index, 0, allocator) catch |err| {
        std.debug.print("  Failed to list addresses: {}\n", .{err});
        return;
    };
    defer allocator.free(addrs);

    if (addrs.len == 0) {
        std.debug.print("  (no addresses)\n", .{});
        return;
    }

    for (addrs) |addr| {
        // Print address with prefix length
        std.debug.print("  ", .{});
        addr.ip.format(std.io.getStdErr().writer()) catch {};

        const scope_name = switch (addr.scope) {
            0 => "global",
            200 => "site",
            253 => "link",
            254 => "host",
            else => "unknown",
        };

        std.debug.print("/{d} scope {s}", .{ addr.prefix_len, scope_name });

        const label = addr.getLabel();
        if (label.len > 0) {
            std.debug.print(" label {s}", .{label});
        }

        std.debug.print("\n", .{});
    }
}
