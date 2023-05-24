const std = @import("std");
const network = @import("network");
const clap = @import("clap");

const debug = std.debug;

const Item = @import("item.zig");
const Type = Item.Type;

const Response = union(enum) {
    directory: struct {
        items: []const Item,

        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            for (self.items) |item| {
                item.deinit(allocator);
            }
            allocator.free(self.items);
        }
    },
    file: struct {
        data: []const u8,

        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }
    },
    pub fn deinit(self: Response, allocator: std.mem.Allocator) void {
        switch (self) {
            .directory => |dir| dir.deinit(allocator),
            .file => |file| file.deinit(allocator),
        }
    }
};

pub fn request(allocator: std.mem.Allocator, name: []const u8, port: u16, selector: []const u8, request_type: Type) !Response {
    //Connect to the gopher server
    const connection = try network.connectToHost(allocator, name, port, .tcp);
    defer connection.close();

    //Send the selector
    _ = try connection.writer().writeAll(selector);
    _ = try connection.writer().writeAll("\r\n");

    switch (request_type) {
        .directory => {
            //Create the list that will contain all of our items
            var items = std.ArrayList(Item).init(allocator);
            errdefer {
                for (items.items) |item| {
                    item.deinit(allocator);
                }

                items.deinit();
            }

            //Create the buffer that contains the working line
            var working_line = try allocator.alloc(u8, 1024);
            defer allocator.free(working_line);
            while (true) {
                var raw_type = try connection.reader().readByte();

                // debug.print("type: {d}/{c}\n", .{ raw_type, raw_type });

                //If the server a `.` that marks the end of the connection, so lets break out
                if (raw_type == '.') {
                    break;
                }

                var line_type = @intToEnum(Type, raw_type);

                var line = try connection.reader().readUntilDelimiterOrEof(working_line, '\n') orelse break;

                //Strip out the \r from the end
                line = line[0 .. line.len - 1];

                //If the line type is valid,
                if (line_type.isValid()) {
                    //Print the nice name of the type
                    // debug.print("line: {s} \"{s}\"\n", .{ @tagName(line_type), line });

                    //Get the index of the first TAB
                    var idx1 = std.mem.indexOf(u8, line, "\t") orelse @panic("Invalid gopher line!");
                    var idx2 = std.mem.indexOfPos(u8, line, idx1 + 1, "\t") orelse @panic("Invalid gopher line!");
                    var idx3 = std.mem.indexOfPos(u8, line, idx2 + 1, "\t") orelse @panic("Invalid gopher line!");

                    try items.append(Item{
                        .type = line_type,
                        .display_string = try allocator.dupe(u8, line[0..idx1]),
                        .selector = try allocator.dupe(u8, line[(idx1 + 1)..idx2]),
                        .host = try allocator.dupe(u8, line[(idx2 + 1)..idx3]),
                        .port = try std.fmt.parseInt(u16, line[(idx3 + 1)..], 0),
                    });
                } else {
                    //Print the raw ascii version of the type
                    // debug.print("line: {c} \"{s}\"\n", .{ raw_type, line });
                }
            }

            return .{ .directory = .{ .items = try items.toOwnedSlice() } };
        },
        .file => {
            var file = try connection.reader().readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(file);
            return .{ .file = .{ .data = try allocator.dupe(u8, file[0 .. file.len - 3]) } };
        },
        else => @panic("Cannot make a request with that type"),
    }
}

fn printGopherspace(response: Response, unicode: bool) !void {
    var selectable_counter: usize = 0;
    for (response.directory.items) |itema| {
        var item: Item = itema;

        if (item.type.selectable()) {
            debug.print("[{d}] ", .{selectable_counter});
            selectable_counter += 1;
        }

        var type_prefix = switch (item.type) {
            .file => if (unicode) "🗏" else "F ",
            .directory => if (unicode) "📁" else "D ",
            else => "",
        };

        debug.print("{s}{s}", .{ type_prefix, item.display_string });

        switch (item.type) {
            .file, .directory => {
                debug.print(" ({s}:{d} {s})", .{ item.host, item.port, item.selector });
            },
            else => {},
        }

        debug.print("\n", .{});
    }
}

pub fn main() !void {
    var stdin = std.io.getStdIn();
    defer stdin.close();

    const unicode = !std.mem.eql(u8, std.os.getenv("TERM") orelse "vt100", "vt100");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == .leak) {
            @panic("Leak!!");
        }
    }

    //The help parameters
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-p, --port <u16>   An option parameter, which takes a value.
        \\<str>...  The host to connect to
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

    if (parsed_args.positionals.len == 0)
        return clap.usage(std.io.getStdErr().writer(), clap.Help, &params);

    var original_host = parsed_args.positionals[0];
    var original_port = if (parsed_args.args.port) |arg_port| arg_port else 70;
    var original_selector = "";

    var host: ?[]const u8 = null;
    var port: ?u16 = null;
    var selector: ?[]const u8 = null;

    defer {
        if (host) |host_val| {
            allocator.free(host_val);
            host = null;
        }
        if (selector) |selector_val| {
            allocator.free(selector_val);
            selector = null;
        }
    }

    //Init network
    try network.init();
    defer network.deinit();

    var response: ?Response = null;
    defer if (response) |res|
        res.deinit(allocator);

    var next_request_type: ?Type = .directory;
    while (true) {
        if (next_request_type != null) {
            //If response exists, free it
            if (response) |res| {
                res.deinit(allocator);
                response = null;
            }

            //Make a request
            response = try request(
                allocator,
                host orelse original_host,
                port orelse original_port,
                selector orelse original_selector,
                next_request_type.?,
            );

            next_request_type = null;
        }

        //Print the gopherspace
        try printGopherspace(response.?, unicode);

        debug.print("[?] ", .{});
        var read = try stdin.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', 10000) orelse break;
        defer allocator.free(read);

        //If they didnt type anything, just try again
        if (read.len == 0) {
            continue;
        }

        //q = quit
        if (read[0] == 'q') {
            break;
        }

        var choice = try std.fmt.parseInt(usize, read, 0);

        var selectable_counter: usize = 0;
        for (response.?.directory.items) |itema| {
            var item: Item = itema;

            if (!item.type.selectable()) {
                continue;
            }

            if (selectable_counter == choice) {
                if (host) |host_val| {
                    allocator.free(host_val);
                    host = null;
                }
                if (selector) |selector_val| {
                    allocator.free(selector_val);
                    selector = null;
                }
                host = try allocator.dupe(u8, item.host);
                selector = try allocator.dupe(u8, item.selector);
                port = item.port;
                next_request_type = item.type;
                break;
            }

            selectable_counter += 1;
        }
    }
}
