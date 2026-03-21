// manage_routes.zig - Add, list, and remove routes
//
// This example demonstrates route management:
//   1. Creates a dummy interface for testing
//   2. Assigns an IP address so the interface can carry routes
//   3. Adds a route with a gateway
//   4. Lists all IPv4 routes
//   5. Deletes the route
//   6. Cleans up the interface
//
// Equivalent commands:
//   ip link add dummy2 type dummy
//   ip link set dummy2 up
//   ip addr add 10.0.0.1/24 dev dummy2
//   ip route add 10.100.0.0/16 via 10.0.0.254 dev dummy2
//   ip route show
//   ip route del 10.100.0.0/16 via 10.0.0.254 dev dummy2
//   ip link del dummy2
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

    // Step 1: Create a dummy interface (ip link add dummy2 type dummy)
    std.debug.print("Creating dummy interface 'dummy2'...\n", .{});
    var dummy_attrs = netlink.LinkAttrs{};
    dummy_attrs.setName("dummy2");
    dummy_attrs.link_type = .dummy;

    netlink.linkAdd(&sock, &dummy_attrs) catch |err| {
        std.debug.print("Failed to create dummy2: {}\n", .{err});
        return err;
    };

    const dummy = netlink.linkByName(&sock, "dummy2") catch |err| {
        std.debug.print("Failed to find dummy2: {}\n", .{err});
        return err;
    };
    const link_index = dummy.index;
    std.debug.print("Created 'dummy2' with index {d}.\n", .{link_index});

    // Bring the interface up (ip link set dummy2 up)
    netlink.linkSetUp(&sock, link_index) catch |err| {
        std.debug.print("Failed to bring dummy2 up: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };

    // Add an address so the interface can carry routes
    // (ip addr add 10.0.0.1/24 dev dummy2)
    std.debug.print("Assigning 10.0.0.1/24 to dummy2...\n", .{});
    const local_net = netlink.parseIPNet("10.0.0.1/24") catch unreachable;
    var local_addr = netlink.Addr{
        .ip = local_net.ip,
        .prefix_len = local_net.prefix_len,
        .link_index = link_index,
    };
    netlink.addrAdd(&sock, link_index, &local_addr) catch |err| {
        std.debug.print("Failed to add address: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };

    // Step 2: Add a route (ip route add 10.100.0.0/16 via 10.0.0.254 dev dummy2)
    std.debug.print("\nAdding route 10.100.0.0/16 via 10.0.0.254...\n", .{});
    const dst_net = netlink.parseIPNet("10.100.0.0/16") catch unreachable;
    const gw_ip = netlink.parseIP("10.0.0.254") catch unreachable;

    const route = netlink.Route{
        .link_index = link_index,
        .dst = dst_net,
        .gw = gw_ip,
        .scope = .universe,
        .protocol = .boot,
    };

    netlink.routeAdd(&sock, &route) catch |err| {
        std.debug.print("Failed to add route: {}\n", .{err});
        netlink.linkDel(&sock, link_index) catch {};
        return err;
    };
    std.debug.print("Route added.\n", .{});

    // Step 3: List all IPv4 routes (ip route show)
    std.debug.print("\nIPv4 routing table:\n", .{});
    listRoutes(&sock, allocator);

    // Step 4: Delete the route (ip route del 10.100.0.0/16 via 10.0.0.254)
    std.debug.print("\nDeleting route 10.100.0.0/16 via 10.0.0.254...\n", .{});
    netlink.routeDel(&sock, &route) catch |err| {
        std.debug.print("Failed to delete route: {}\n", .{err});
    };
    std.debug.print("Route deleted.\n", .{});

    // Verify the route is gone
    std.debug.print("\nIPv4 routing table after deletion:\n", .{});
    listRoutes(&sock, allocator);

    // Step 5: Cleanup (ip link del dummy2)
    std.debug.print("\nCleaning up...\n", .{});
    netlink.linkDel(&sock, link_index) catch |err| {
        std.debug.print("Warning: failed to delete dummy2: {}\n", .{err});
    };
    std.debug.print("Deleted 'dummy2'.\n", .{});
    std.debug.print("Done.\n", .{});
}

fn listRoutes(sock: *netlink.NetlinkSocket, allocator: std.mem.Allocator) void {
    // List IPv4 routes (family = AF_INET = 2)
    const routes = netlink.routeList(sock, 2, allocator) catch |err| {
        std.debug.print("  Failed to list routes: {}\n", .{err});
        return;
    };
    defer allocator.free(routes);

    if (routes.len == 0) {
        std.debug.print("  (no routes)\n", .{});
        return;
    }

    const writer = std.io.getStdErr().writer();

    for (routes) |route| {
        std.debug.print("  ", .{});

        // Destination
        if (route.dst) |dst| {
            dst.ip.format(writer) catch {};
            std.debug.print("/{d}", .{dst.prefix_len});
        } else {
            std.debug.print("default", .{});
        }

        // Gateway
        if (route.gw) |gw| {
            std.debug.print(" via ", .{});
            gw.format(writer) catch {};
        }

        // Output interface
        if (route.link_index != 0) {
            // Look up interface name
            const link = netlink.linkByIndex(sock, route.link_index) catch null;
            if (link) |l| {
                std.debug.print(" dev {s}", .{l.getName()});
            } else {
                std.debug.print(" dev idx:{d}", .{route.link_index});
            }
        }

        // Scope
        std.debug.print(" scope {s}", .{route.scope.toString()});

        // Source
        if (route.src) |src| {
            std.debug.print(" src ", .{});
            src.format(writer) catch {};
        }

        std.debug.print("\n", .{});
    }
}
