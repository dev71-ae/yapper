const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const openssl_include_dir = b.option(
        []const u8,
        "openssl_include_dir",
        "The directory containing `openssl/ssl.h` header file",
    ) orelse return error.RequiredOption;

    const source = b.dependency("tquic", .{});

    const module = b.addModule("tquic", .{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = buildQtuic(b, source, target, optimize);

    module.linkLibrary(lib);

    module.addIncludePath(source.path("include"));
    module.addIncludePath(.{ .cwd_relative = openssl_include_dir });

    b.installArtifact(lib);
}

pub fn buildQtuic(
    b: *Build,
    source: *Build.Dependency,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "tquic",
        .target = target,
        .optimize = optimize,
    });

    const build_lib = b.addSystemCommand(&.{"cargo"});
    build_lib.setCwd(source.path(""));

    switch (target.result.os.tag) {
        .ios => build_lib.addArg("lipo"),
        .macos, .linux, .freebsd, .windows => build_lib.addArg("build"),
        else => if (target.result.abi == .android) build_lib.addArgs(&.{
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

    const folder = switch (optimize) {
        .ReleaseSafe, .ReleaseFast, .ReleaseSmall => out: {
            build_lib.addArg("--release");
            break :out "release";
        },
        .Debug => "debug",
    };

    lib.addObjectFile(target_dir.path(b, b.fmt("{s}/libtquic.a", .{folder})));
    lib.installHeadersDirectory(source.path("include"), "", .{});

    return lib;
}
