const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const openssl_include_dir: []const u8 =
        std.process.getEnvVarOwned(b.allocator, "OPENSSL_INCLUDE_DIR") catch |e|
        std.debug.panic("Error getting `OPENSSL_INCLUDE_DIR environment` variable: {}", .{e});

    const tquic = b.dependency("tquic", .{
        .target = target,
        .optimize = optimize,
        .openssl_include_dir = openssl_include_dir,
    });

    const xev = b.dependency("libxev", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "scratch",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("xev", xev.module("xev"));
    exe.root_module.addImport("tquic", tquic.module("tquic"));

    exe.addIncludePath(.{ .cwd_relative = openssl_include_dir });
    exe.addIncludePath(tquic.artifact("tquic").getEmittedIncludeTree());

    b.installArtifact(exe);

    // :run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // :test
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
