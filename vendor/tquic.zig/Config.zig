const c = @import("c.zig").c;
const TlsConfigSelector = @import("TlsConfig.zig").Selector;

handle: *c.quic_config_t,

const Self = @This();

pub fn init() !Self {
    const handle = c.quic_config_new() orelse return error.TQuicFailed;
    return .{ .handle = handle };
}

pub fn deinit(self: *Self) void {
    c.quic_config_free(self.handle);
}

pub fn set_max_idle_timeout(self: *Self, length: u64) void {
    c.quic_config_set_max_idle_timeout(self.handle, length);
}

pub fn set_recv_udp_payload_size(self: *Self, size: u16) void {
    c.quic_config_set_recv_udp_payload_size(self.handle, size);
}

pub fn set_tls_selector(
    self: *Self,
    ctx: anytype,
    selector: TlsConfigSelector(@TypeOf(ctx)),
) void {
    c.quic_config_set_tls_selector(self.handle, .{
        .get_default = selector.get_default,
        .select = selector.select,
    }, ctx);
}
