const std = @import("std");
const builtin = @import("builtin");
const CrossTarget = std.zig.CrossTarget;

const RustProfile = enum { Release, Debug };

// Adapted from https://github.com/tigerbeetle/tigerbeetle/blob/5159e60472d154dfcf43f44d5bc36d2f8186913f/build.zig#L14
fn resolveTarget(
    b: *std.Build,
    target: []const u8,
) !std.Build.ResolvedTarget {
    const triples = .{
        "x86_64-ios",
        "x86_64-macos",
        "x86_64-linux",
        "x86_64-windows",
        "x86_64-freebsd",
        "aarch64-ios",
        "aarch64-macos",
        "aarch64-linux",
        "aarch64-windows",
        "aarch64-freebsd",
    };

    const arch_os = inline for (triples) |triple| {
        if (std.mem.eql(u8, target, triple)) break triple;
    } else {
        std.log.err("unsupported target: '{s}'", .{target});
        return error.UnsupportedTarget;
    };

    return b.resolveTargetQuery(try CrossTarget.parse(
        .{ .arch_os_abi = arch_os },
    ));
}

pub fn build(b: *std.Build) !void {
    const host_target = @tagName(builtin.target.cpu.arch) ++ "-" ++ @tagName(builtin.target.os.tag);

    const target = b.option([]const u8, "target", "The target triples to build for. default: host") orelse host_target;
    const profile = b.option(
        RustProfile,
        "profile",
        "To release, or not to release, that is the question. default: release",
    ) orelse RustProfile.Release;

    const resolved_target = try resolveTarget(b, target);

    const tquic = b.dependency("tquic", .{});
    const lib = b.addStaticLibrary(.{
        .name = "tquic",
        .target = resolved_target, // Has no effect
        .optimize = .ReleaseFast, // Has no effect
    });

    const build_lib = b.addSystemCommand(&.{"cargo"});
    build_lib.setCwd(tquic.path(""));

    switch (resolved_target.result.os.tag) {
        .ios => build_lib.addArg("lipo"),
        .macos, .linux, .freebsd, .windows => build_lib.addArg("build"),
        else => if (resolved_target.result.abi == .android) build_lib.addArgs(&.{
            "ndk",
            "-t",
            @panic("TODO: Android Arch"),
            "-p",
            "22",
            "--",
        }) else unreachable,
    }

    const target_dir = build_lib.addPrefixedOutputDirectoryArg("--target-dir=", "target");

    build_lib.addArgs(&.{ "-F", "ffi" });

    if (profile == .Release) build_lib.addArg("--release");

    lib.step.dependOn(&build_lib.step);

    lib.addObjectFile(target_dir.path(b, "release/libtquic.a"));
    lib.installHeadersDirectory(tquic.path("include"), "", .{});

    b.installArtifact(lib);
}
