const std = @import("std");
const builtin = @import("builtin");

const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("tquic", .{});

    const module = b.addModule("tquic", .{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const crate = buildQtuic(b, upstream, target, optimize);
    const artifact = b.addInstallArtifact(crate, .{});

    // :test
    // :tools
}

pub fn buildQtuic(
    b: *Build,
    source: *Build.Dependency,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *Build.Step.Compile {}
