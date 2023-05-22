const std = @import("std");
const network = @import("network");

pub fn main() !void {
    try network.init();
    defer network.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak detected!");
    const allocator = gpa.allocator();
    _ = allocator;

    var socket = try network.Socket.create(.ipv4, .tcp);
    defer socket.close();

    //Bind to port 70 (gopher)
    // try socket.bindToPort(70);
    try socket.bindToPort(7777);

    try socket.listen();

    while (true) {}
}
