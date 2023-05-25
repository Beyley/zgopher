const std = @import("std");
const network = @import("network");
const clap = @import("clap");

const ServerConfig = @import("server_config.zig");

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

    //The default config
    var config = ServerConfig{};

    //Open the config file, if the file isnt found, create a new file
    var config_file = std.fs.cwd().openFile("config.json", .{}) catch |err| if (err == std.fs.File.OpenError.FileNotFound) try std.fs.cwd().createFile("config.json", .{ .read = true }) else return err;

    //If the file is blank,
    if (try config_file.getEndPos() == 0) {
        //Write the default config to the file
        try std.json.stringify(config, .{}, config_file.writer());

        //Seek back to the start
        try config_file.seekTo(0);
    }

    //Create a reader to stream the JSON tokens from the file
    var reader = std.json.reader(allocator, config_file.reader());

    //Parse the config from the reader
    config = try std.json.parseFromTokenSource(ServerConfig, allocator, &reader, .{});
    defer std.json.parseFree(ServerConfig, allocator, config);

    //Close the file, since we dont need it anymore
    config_file.close();

    const port_number = if (parsed_args.args.port) |port| port else config.port;

    var socket = try network.Socket.create(.ipv4, .tcp);
    defer socket.close();

    try socket.bindToPort(port_number);

    try socket.listen();

    std.debug.print("Listening...\n", .{});

    while (true) {
        var client = try socket.accept();

        //Spawn a new thread to handle the client
        var t = try std.Thread.spawn(.{}, runClient, .{ client, allocator });
        //Detatch the thread, let it LIVE
        t.detach();
    }
}

fn runClient(client: network.Socket, allocator: std.mem.Allocator) !void {
    defer client.close();

    //Create a new buffer to store our working data
    var buf = try allocator.alloc(u8, 1024);
    defer allocator.free(buf);

    //Print that we have got a new client
    std.debug.print("Client connected from {}.\n", .{
        try client.getLocalEndPoint(),
    });

    var reader = client.reader();
    var writer = client.writer();

    //Read until the next \n, if EOF, return out
    var selector = (try reader.readUntilDelimiterOrEof(buf, '\n') orelse return);

    //Strip the \r at the end
    selector = selector[0 .. selector.len - 1];

    //Print the selector we recieved
    std.debug.print("Got selector \"{s}\"\n", .{selector});

    try writer.writeAll("iThis is a test!\t\terror.host\t1\r\n");
    //Write the end of the connection
    try writer.writeAll(".\r\n");
}
