pub const c = @import("c.zig").c;
const std = @import("std");

pub const Config = @import("Config.zig");
pub const TlsConfig = @import("TLSConfig.zig");

pub const ApplicationProtos = packed struct {
    interop: bool = false,
    http09: bool = false,
    h3: bool = true,

    pub fn to_slice(self: ApplicationProtos) []const []const u8 {
        var result: [3][]const u8 = undefined;
        var index: usize = 0;

        if (self.interop) {
            result[index] = "hq-interop";
            index += 1;
        }

        if (self.http09) {
            result[index] = "http09";
            index += 1;
        }

        if (self.h3) {
            result[index] = "h3";
            index += 1;
        }

        return result[0..index];
    }
};

pub const Logger = struct {
    pub const Level = enum {
        Off,
        Error,
        Warn,
        Info,
        Debug,
        Trace,

        pub fn to_slice(self: Level) []const u8 {
            return switch (self) {
                .Off => "OFF",
                .Error => "ERROR",
                .Warn => "WARN",
                .Info => "INFO",
                .Debug => "DEBUG",
                .Trace => "TRACE",
            };
        }
    };

    pub fn set(level: Level) void {
        c.quic_set_logger(null, null, level.to_slice().ptr);
    }
};
