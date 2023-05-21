const std = @import("std");
const network = @import("network");

const Item = @import("item.zig");
const Type = Item.Type;

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

    //Connect to the gopher server
    const connection = try network.connectToHost(allocator, "gopher.floodgap.com", 70, .tcp);
    defer connection.close();

    //The selector to send
    const selector = "";

    //Send the selector
    _ = try connection.writer().writeAll(selector ++ "\r\n");

    //Create the list that will contain all of our items
    var items = std.ArrayList(Item).init(allocator);
    defer {
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
            std.debug.print("line: {s} \"{s}\"\n", .{ @tagName(line_type), line });

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
            std.debug.print("line: {c} \"{s}\"\n", .{ raw_type, line });
        }
    }

    for (items.items) |itema| {
        var item: Item = itema;

        var type_prefix = switch (item.type) {
            .file => "F ",
            .directory => "D ",
            else => "",
        };

        std.debug.print("{s}{s}", .{ type_prefix, item.display_string });
        std.debug.print("\n", .{});
    }
}
