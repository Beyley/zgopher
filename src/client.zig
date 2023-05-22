const std = @import("std");
const network = @import("network");

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
            defer items.deinit();

            //Create the buffer that contains the working line
            var working_line = try allocator.alloc(u8, 1024);
            defer allocator.free(working_line);
            while (true) {
                var raw_type = try connection.reader().readByte();

                // std.debug.print("type: {d}/{c}\n", .{ raw_type, raw_type });

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
                    // std.debug.print("line: {s} \"{s}\"\n", .{ @tagName(line_type), line });

                    //Get the index of the first TAB
                    var idx1 = std.mem.indexOf(u8, line, "\t") orelse @panic("Invalid gopher line!");
                    var idx2 = std.mem.indexOfPos(u8, line, idx1 + 1, "\t") orelse @panic("Invalid gopher line!");
                    var idx3 = std.mem.indexOfPos(u8, line, idx2 + 1, "\t") orelse @panic("Invalid gopher line!");

                    try items.append(Item{
                        .type = line_type,
                        .display_string = try allocator.dupe(u8, line[0..idx1]),
                        .selector = try allocator.dupe(u8, line[(idx1 + 1)..idx2]),
                        .hostname = try allocator.dupe(u8, line[(idx2 + 1)..idx3]),
                        .port = try std.fmt.parseInt(u16, line[(idx3 + 1)..], 0),
                    });
                } else {
                    //Print the raw ascii version of the type
                    // std.debug.print("line: {c} \"{s}\"\n", .{ raw_type, line });
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == .leak) {
            @panic("Leak!!");
        }
    }

    //Init network
    try network.init();
    defer network.deinit();

    var response = try request(
        allocator,
        "gopher.floodgap.com",
        70,
        "",
        .directory,
    );
    defer response.deinit(allocator);

    for (response.directory.items) |itema| {
        var item: Item = itema;

        var type_prefix = switch (item.type) {
            .file => "F ",
            .directory => "D ",
            else => "",
        };

        std.debug.print("{s}{s}", .{ type_prefix, item.display_string });

        switch (item.type) {
            .file, .directory => {
                std.debug.print(" ({s}:{d} {s})", .{ item.hostname, item.port, item.selector });
            },
            else => {},
        }

        std.debug.print("\n", .{});
    }

    var file_response = try request(
        allocator,
        "gopher.floodgap.com",
        70,
        "/ptloma",
        .file,
    );
    defer file_response.deinit(allocator);

    std.debug.print("\n\n\nFILE: {s}\n", .{file_response.file.data});
}
