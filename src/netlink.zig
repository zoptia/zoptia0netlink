// Package netlink provides a Zig library for Linux netlink communication.
// Netlink is the interface a user-space program in Linux uses to communicate
// with the kernel. It can be used to add and remove interfaces, set up IP
// addresses and routes, and configure network features. Netlink communication
// requires elevated privileges, so in most cases this code needs to run as root.

pub const nl = @import("nl.zig");
pub const types = @import("types.zig");
pub const link = @import("link.zig");
pub const addr = @import("addr.zig");
pub const route = @import("route.zig");
pub const neigh = @import("neigh.zig");

// Re-export primary types for convenience
pub const Address = nl.Address;
pub const NetlinkSocket = nl.NetlinkSocket;
pub const LinkAttrs = types.LinkAttrs;
pub const LinkType = types.LinkType;
pub const LinkOperState = types.LinkOperState;
pub const Addr = types.Addr;
pub const IPNet = types.IPNet;
pub const Route = types.Route;
pub const Neigh = types.Neigh;
pub const Scope = types.Scope;
pub const RouteProtocol = types.RouteProtocol;
pub const LinkStatistics = types.LinkStatistics;

// Re-export primary functions for convenience

// Link operations
pub const linkAdd = link.linkAdd;
pub const linkDel = link.linkDel;
pub const linkList = link.linkList;
pub const linkByName = link.linkByName;
pub const linkByIndex = link.linkByIndex;
pub const linkSetUp = link.linkSetUp;
pub const linkSetDown = link.linkSetDown;
pub const linkSetMTU = link.linkSetMTU;
pub const linkSetName = link.linkSetName;
pub const linkSetMaster = link.linkSetMaster;
pub const linkSetNoMaster = link.linkSetNoMaster;
pub const linkSetARPOff = link.linkSetARPOff;
pub const linkSetARPOn = link.linkSetARPOn;
pub const linkSetPromiscOn = link.linkSetPromiscOn;
pub const linkSetPromiscOff = link.linkSetPromiscOff;
pub const linkSetHardwareAddr = link.linkSetHardwareAddr;

// Address operations
pub const addrAdd = addr.addrAdd;
pub const addrReplace = addr.addrReplace;
pub const addrDel = addr.addrDel;
pub const addrList = addr.addrList;

// Route operations
pub const routeAdd = route.routeAdd;
pub const routeReplace = route.routeReplace;
pub const routeDel = route.routeDel;
pub const routeList = route.routeList;
pub const routeListFiltered = route.routeListFiltered;

// Neighbor operations
pub const neighAdd = neigh.neighAdd;
pub const neighSet = neigh.neighSet;
pub const neighAppend = neigh.neighAppend;
pub const neighDel = neigh.neighDel;
pub const neighList = neigh.neighList;

// Utility functions
pub const parseIPNet = types.parseIPNet;
pub const parseIP = types.parseIP;
pub const newIPNet = types.newIPNet;
pub const computeBroadcast = types.computeBroadcast;

test {
    @import("std").testing.refAllDecls(@This());
}
