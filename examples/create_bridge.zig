// create_bridge.zig - Create a bridge with a dummy interface as a port
//
// This example creates a Linux bridge device, adds a dummy interface to it
// as a port, and brings the bridge up. It then cleans up by removing both
// interfaces.
//
// Equivalent commands:
//   ip link add br0 type bridge
//   ip link add dummy0 type dummy
//   ip link set dummy0 master br0
//   ip link set br0 up
//
// Cleanup:
//   ip link del br0
//   ip link del dummy0
//
// Requires root privileges.

const std = @import("std");
const netlink = @import("netlink");

pub fn main() !void {
    // Open a netlink socket
    var sock = netlink.NetlinkSocket.open(0) catch |err| {
        std.debug.print("Failed to open netlink socket: {}\n", .{err});
        std.debug.print("This program requires root privileges.\n", .{});
        return err;
    };
    defer sock.close();

    // Step 1: Create a bridge device (ip link add br0 type bridge)
    std.debug.print("Creating bridge 'br0'...\n", .{});
    var bridge_attrs = netlink.LinkAttrs{};
    bridge_attrs.setName("br0");
    bridge_attrs.link_type = .bridge;

    netlink.linkAdd(&sock, &bridge_attrs) catch |err| {
        std.debug.print("Failed to create bridge: {}\n", .{err});
        return err;
    };
    std.debug.print("Bridge 'br0' created.\n", .{});

    // Look up the bridge to get its index
    const bridge = netlink.linkByName(&sock, "br0") catch |err| {
        std.debug.print("Failed to find bridge 'br0': {}\n", .{err});
        return err;
    };
    std.debug.print("Bridge 'br0' has index {d}.\n", .{bridge.index});

    // Step 2: Create a dummy interface (ip link add dummy0 type dummy)
    std.debug.print("Creating dummy interface 'dummy0'...\n", .{});
    var dummy_attrs = netlink.LinkAttrs{};
    dummy_attrs.setName("dummy0");
    dummy_attrs.link_type = .dummy;

    netlink.linkAdd(&sock, &dummy_attrs) catch |err| {
        std.debug.print("Failed to create dummy interface: {}\n", .{err});
        // Clean up: remove the bridge we already created
        netlink.linkDel(&sock, bridge.index) catch {};
        return err;
    };
    std.debug.print("Dummy interface 'dummy0' created.\n", .{});

    // Look up the dummy interface to get its index
    const dummy = netlink.linkByName(&sock, "dummy0") catch |err| {
        std.debug.print("Failed to find dummy interface 'dummy0': {}\n", .{err});
        netlink.linkDel(&sock, bridge.index) catch {};
        return err;
    };
    std.debug.print("Dummy interface 'dummy0' has index {d}.\n", .{dummy.index});

    // Step 3: Add dummy0 as a port of br0 (ip link set dummy0 master br0)
    std.debug.print("Adding 'dummy0' as port of 'br0'...\n", .{});
    netlink.linkSetMaster(&sock, dummy.index, bridge.index) catch |err| {
        std.debug.print("Failed to set master: {}\n", .{err});
        netlink.linkDel(&sock, dummy.index) catch {};
        netlink.linkDel(&sock, bridge.index) catch {};
        return err;
    };
    std.debug.print("'dummy0' is now a port of 'br0'.\n", .{});

    // Step 4: Bring the bridge up (ip link set br0 up)
    std.debug.print("Bringing 'br0' up...\n", .{});
    netlink.linkSetUp(&sock, bridge.index) catch |err| {
        std.debug.print("Failed to bring bridge up: {}\n", .{err});
        netlink.linkDel(&sock, dummy.index) catch {};
        netlink.linkDel(&sock, bridge.index) catch {};
        return err;
    };
    std.debug.print("Bridge 'br0' is up.\n", .{});

    // Verify the setup by re-reading the bridge
    const updated_bridge = netlink.linkByName(&sock, "br0") catch |err| {
        std.debug.print("Failed to verify bridge: {}\n", .{err});
        netlink.linkDel(&sock, dummy.index) catch {};
        netlink.linkDel(&sock, bridge.index) catch {};
        return err;
    };
    std.debug.print("\nVerification:\n", .{});
    std.debug.print("  Bridge 'br0': index={d}, state={s}, mtu={d}\n", .{
        updated_bridge.index,
        updated_bridge.oper_state.toString(),
        updated_bridge.mtu,
    });

    // Verify that dummy0 has br0 as master
    const updated_dummy = netlink.linkByName(&sock, "dummy0") catch |err| {
        std.debug.print("Failed to verify dummy: {}\n", .{err});
        netlink.linkDel(&sock, dummy.index) catch {};
        netlink.linkDel(&sock, bridge.index) catch {};
        return err;
    };
    std.debug.print("  Dummy 'dummy0': index={d}, master_index={d}\n", .{
        updated_dummy.index,
        updated_dummy.master_index,
    });

    // Cleanup: remove interfaces (ip link del dummy0 && ip link del br0)
    std.debug.print("\nCleaning up...\n", .{});
    netlink.linkDel(&sock, dummy.index) catch |err| {
        std.debug.print("Warning: failed to delete dummy0: {}\n", .{err});
    };
    std.debug.print("Deleted 'dummy0'.\n", .{});

    netlink.linkDel(&sock, bridge.index) catch |err| {
        std.debug.print("Warning: failed to delete br0: {}\n", .{err});
    };
    std.debug.print("Deleted 'br0'.\n", .{});

    std.debug.print("Done.\n", .{});
}
