const std = @import("std");
const builtin = @import("builtin");

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
    const artifact = b.addInstallArtifact(crate, .{});

    // :test

    // :tools
}

pub fn buildQtuic(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *Build.Step.Compile {
    const upstream = b.dependency("tquic", .{});
    const cargo = b.addSystemCommand(.{"cargo"});
}
