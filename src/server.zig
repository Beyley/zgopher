const std = @import("std");
const network = @import("network");

pub fn main() !void {
    try network.init();
    defer network.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Memory Leak!");

    const allocator = gpa.allocator();

    const port_number = 7777;

    var socket = try network.Socket.create(.ipv4, .tcp);
    defer socket.close();

    try socket.bindToPort(port_number);

    try socket.listen();

    var buf = try allocator.alloc(u8, 1024);
    defer allocator.free(buf);
    while (true) {
        var client = try socket.accept();
        defer client.close();

        std.debug.print("Client connected from {}.\n", .{
            try client.getLocalEndPoint(),
        });

        var reader = client.reader();
        var writer = client.writer();

        var selector = (try reader.readUntilDelimiterOrEof(buf, '\n') orelse break);

        //Strip the \r at the end
        selector = selector[0 .. selector.len - 1];

        std.debug.print("Got selector \"{s}\"\n", .{selector});

        try writer.writeAll("iThis is a test!\t\terror.host\t1\r\n");
        try writer.writeAll(".\r\n");
    }
}
