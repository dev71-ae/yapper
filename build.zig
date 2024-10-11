const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tquic = b.dependency("tquic", .{
        .target = target,
        .optimize = optimize,
    });

    const xev = b.dependency("libxev", .{
        .target = target,
        .optimize = optimize,
    });

    const server = b.addExecutable(.{
        .name = "yapper",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    server.root_module.addImport("xev", xev.module("xev"));
    server.root_module.addImport("tquic", tquic.module("tquic"));

    b.installArtifact(server);

    // :run
    const run_server = b.addRunArtifact(server);
    run_server.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_server.addArgs(args);
    }

    const run_step = b.step("run", "Run the server");
    run_step.dependOn(&run_server.step);

    // :test
    const server_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_server_unit_tests = b.addRunArtifact(server_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_server_unit_tests.step);
}
