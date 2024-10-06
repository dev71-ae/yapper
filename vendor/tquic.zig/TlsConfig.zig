const c = @import("c.zig").c;
const ApplicationProtos = @import("lib.zig").ApplicationProtos;

handle: *c.quic_tls_config_t,

const Self = @This();

pub fn Selector(comptime ctx: type) type {
    return struct {
        get_default: fn (ctx: *ctx) ?Self,
        select: fn (ctx: *ctx, server_name: []const u8) ?Self,
    };
}

pub fn initServer(
    cert_file: []const u8,
    key_file: []const u8,
    protos: ApplicationProtos,
    enable_early_data: bool,
) !Self {
    const protos_slice = protos.to_slice();

    const handle = c.quic_tls_config_new_server_config(
        cert_file.ptr,
        key_file.ptr,
        @ptrCast(protos_slice.ptr),
        @intCast(protos_slice.len),
        enable_early_data,
    ) orelse return error.TQuicError;

    return .{ .handle = handle };
}

pub fn deinit(self: *Self) void {
    c.quic_tls_config_free(self.handle);
}
