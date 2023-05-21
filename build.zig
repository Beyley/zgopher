const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("network", .{
        .source_file = .{ .path = "libs/zig-network/network.zig" },
    });

    const server = b.addExecutable(.{
        .name = "zgs",
        .root_source_file = .{ .path = "src/server.zig" },
        .target = target,
        .optimize = optimize,
    });
    server.addModule("network", module);

    b.installArtifact(server);

    const client = b.addExecutable(.{
        .name = "zgc",
        .root_source_file = .{ .path = "src/client.zig" },
        .target = target,
        .optimize = optimize,
    });
    client.addModule("network", module);

    b.installArtifact(client);

    const client_run_cmd = b.addRunArtifact(client);
    client_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        client_run_cmd.addArgs(args);
    }
    const client_run_step = b.step("run-client", "Run the app");
    client_run_step.dependOn(&client_run_cmd.step);

    const server_run_cmd = b.addRunArtifact(server);
    server_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        server_run_cmd.addArgs(args);
    }
    const server_run_step = b.step("run-server", "Run the app");
    server_run_step.dependOn(&server_run_cmd.step);
}
