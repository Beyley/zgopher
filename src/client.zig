const std = @import("std");
const network = @import("network");

const item = @import("item.zig");
const Type = item.Type;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == .leak) {
            @panic("Leak!!");
        }
    }

    try network.init();
    defer network.deinit();

    const sock = try network.connectToHost(allocator, "gopher.floodgap.com", 70, .tcp);
    defer sock.close();

    _ = try sock.send("\r\n");

    var buf = try allocator.alloc(u8, 1024);
    defer allocator.free(buf);
    while (true) {
        var raw_type = try sock.reader().readByte();

        // std.debug.print("type: {d}/{c}\n", .{ raw_type, raw_type });

        //If the server a `.` that marks the end of the connection, so lets break out
        if (raw_type == '.') {
            break;
        }

        var line_type = @intToEnum(Type, raw_type);

        var line = try sock.reader().readUntilDelimiterOrEof(buf, '\n') orelse break;

        //Strip out the \r from the end
        line = line[0 .. line.len - 1];

        //If the line type is valid,
        if (line_type.isValid()) {
            //Print the nice name of the type
            std.debug.print("line: {s} \"{s}\"\n", .{ @tagName(line_type), line });
        } else {
            //Print the raw ascii version of the type
            std.debug.print("line: {c} \"{s}\"\n", .{ raw_type, line });
        }
    }
}
