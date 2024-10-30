const std = @import("std");
const builtin = @import("builtin");
const RustTarget = @import("rust_target.zig").Target;

const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("tquic", .{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const crate = buildQtuic(b, target, optimize);
    module.linkLibrary(crate);

    // :test
    const module_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    module_unit_tests.linkLibrary(crate);

    const run_module_unit_tests = b.addRunArtifact(module_unit_tests);
    const test_step = b.step("test", "Run module unit tests");
    test_step.dependOn(&run_module_unit_tests.step);
}

pub fn buildQtuic(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *Build.Step.Compile {
    const upstream = b.dependency("tquic", .{});
    const cargo = b.addSystemCommand(&.{"cargo"});

    const rust_target = b.fmt("{}", .{
        RustTarget.fromZig(target.result) catch @panic("Unable to convert target triple to Rust"),
    });

    cargo.setCwd(upstream.path(""));
    cargo.addArgs(&.{
        "zigbuild",
        "-F",
        "ffi",
        "--target",
        rust_target,
    });

    if (optimize != .Debug) cargo.addArg("--release");

    const target_dir = cargo.addPrefixedOutputDirectoryArg("--target-dir=", "target");
    const lib = b.addStaticLibrary(.{
        .name = "tquic",
        .target = target,
        .optimize = optimize,
    });

    lib.addObjectFile(
        target_dir.path(b, b.fmt("{s}/{s}/libtquic.{s}", .{
            rust_target,
            if (optimize == .Debug) "debug" else "release",
            if (target.result.abi == .msvc) "lib" else "a",
        })),
    );

    return lib;
}
