const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tquic = b.dependency("tquic", .{}).artifact("tquic");
    const xev = b.dependency("libxev", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{
        .name = "scratch",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("xev", xev.module("xev"));

    exe.linkLibrary(tquic);
    exe.linkSystemLibrary("libssl");

    const openssl_lib_dir =
        std.process.getEnvVarOwned(b.allocator, "OPENSSL_LIB_DIR") catch |e|
        std.debug.panic("Error getting OPENSSL_LIB_DIR environment variable: {}", .{e});

    exe.addIncludePath(tquic.getEmittedIncludeTree());
    exe.addIncludePath(.{ .cwd_relative = openssl_lib_dir });

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

    // :check
    const check = b.step("check", "Check if scratch compiles");
    check.dependOn(&exe.step);
}
