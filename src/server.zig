const std = @import("std");
const network = @import("network");
const clap = @import("clap");

pub fn main() !void {
    //The help parameters
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-p, --port <u16>   An option parameter, which takes a value.
        \\
    );

    // Initialize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also pass `.{}` to `clap.parse` if you don't
    // care about the extra information `Diagnostics` provides.
    var diag = clap.Diagnostic{};
    var parsed_args = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer parsed_args.deinit();

    //If they specified help, print the usage string
    if (parsed_args.args.help != 0)
        return clap.usage(std.io.getStdErr().writer(), clap.Help, &params);

    try network.init();
    defer network.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Memory Leak!");

    const allocator = gpa.allocator();

    const port_number = if (parsed_args.args.port) |port| port else 70;

    var socket = try network.Socket.create(.ipv4, .tcp);
    defer socket.close();

    try socket.bindToPort(port_number);

    try socket.listen();

    std.debug.print("Listening...\n", .{});

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
