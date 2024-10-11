const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

pub const Config = opaque {
    const Self = Config;

    extern fn quic_config_new() ?*Self;
    pub inline fn init() !*Self {
        return quic_config_new() orelse error.TQuicError;
    }

    extern fn quic_config_free(self: *Self) void;
    pub const deinit = quic_config_free;

    extern fn quic_config_set_max_idle_timeout(self: *Self, length: u64) void;
    pub const setMaxIdleTimeout = quic_config_set_max_idle_timeout;

    extern fn quic_config_set_recv_udp_payload_size(self: *Self, size: u16) void;
    pub const setRecvUpdPlayloadSize = quic_config_set_recv_udp_payload_size;

    extern fn quic_config_set_tls_selector(
        self: *Self,
        methods: *const TlsConfig.SelectMethods,
        context: *anyopaque,
    ) void;
    pub inline fn setTlsSelector(
        self: *Self,
        context: *anyopaque,
        methods: TlsConfig.SelectMethods,
    ) void {
        quic_config_set_tls_selector(
            self,
            &methods,
            context,
        );
    }
};

pub const TlsConfig = opaque {
    const Self = TlsConfig;

    pub const SelectMethods = extern struct {
        get_default: *const fn (ctx: *anyopaque) callconv(.C) *Self,
        select: *const fn (
            ctx: *anyopaque,
            server_name: [*:0]const u8,
            server_name_len: usize,
        ) callconv(.C) *Self,
    };

    extern fn quic_tls_config_new_server_config(
        cert_file: [*:0]const u8,
        key_file: [*:0]const u8,
        protos: [*]const [*:0]const u8,
        proto_num: isize,
        enable_early_data: bool,
    ) ?*Self;
    pub inline fn initServer(
        cert_file: [*:0]const u8,
        key_file: [*:0]const u8,
        protos: ApplicationProtos,
        enable_early_data: bool,
    ) !*Self {
        const protos_slice = protos.to_slice();
        return quic_tls_config_new_server_config(
            cert_file,
            key_file,
            @ptrCast(protos_slice.ptr),
            @intCast(protos_slice.len),
            enable_early_data,
        ) orelse error.TQuicError;
    }

    extern fn quic_tls_config_free(tls_config: *Self) void;
    pub const deinit = quic_tls_config_free;
};

pub const ApplicationProtos = packed struct {
    interop: bool = false,
    http09: bool = false,
    h3: bool = false,

    pub fn to_slice(self: ApplicationProtos) [][]const u8 {
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

pub const setLogger = Logger.setLogger;
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

    extern fn quic_set_logger(cb: fn (
        data: [*:0]const u8,
        data_len: usize,
        argp: ?*anyopaque,
    ) callconv(.C) void, argp: ?*anyopaque, level: [*:0]const u8) void;

    pub fn setLogger(
        comptime T: type,
        argp: T,
        cb: fn (data: []const u8, argp: T) void,
        level: Level,
    ) void {
        quic_set_logger(struct {
            fn wrapper(data: [*:0]const u8, _: usize, argp_: ?*anyopaque) callconv(.C) void {
                @call(.always_inline, cb, .{ data, @as(T, @ptrCast(@alignCast(argp_))) });
            }
        }.wrapper, @ptrCast(argp), level.to_slice());
    }
};

pub const Connection = opaque {
    pub fn x() void {}
};

pub const PacketInfo = extern struct {
    src: *const posix.sockaddr,
    src_len: posix.socklen_t,
    dst: *const posix.sockaddr,
    dst_len: posix.socklen_t,
};

pub const PacketOutSpec = extern struct {
    iov: [*]const IoVec,
    iovlen: usize,
    src_addr: ?*const anyopaque,
    src_addr_len: posix.socklen_t,
    dst_addr: ?*const anyopaque,
    dst_addr_len: posix.socklen_t,
};

pub const Endpoint = opaque {
    const Self = Endpoint;

    extern fn quic_endpoint_new(
        config: *Config,
        is_server: bool,
        handler_methods: *const TransportHandler,
        handler_ctx: *anyopaque,
        sender_methods: *const PacketSendHandler,
        sender_ctx: *anyopaque,
    ) ?*Self;
    pub inline fn init(
        config: *Config,
        is_server: bool,
        handler_methods: *const TransportHandler,
        handler_ctx: *anyopaque,
        sender_methods: *const PacketSendHandler,
        sender_ctx: *anyopaque,
    ) !*Self {
        return quic_endpoint_new(
            config,
            is_server,
            handler_methods,
            handler_ctx,
            sender_methods,
            sender_ctx,
        ) orelse error.TQuicError;
    }

    extern fn quic_endpoint_free(endpoint: *Self) void;
    pub const deinit = quic_endpoint_free;

    extern fn quic_endpoint_process_connections(endpoint: *Self) void;
    pub const processConnections = quic_endpoint_process_connections;

    extern fn quic_endpoint_recv(endpoint: *Self, buf: [*]u8, buf_len: usize, info: *const PacketInfo) c_int;
    pub const recv = quic_endpoint_recv;

    extern fn quic_endpoint_timeout(self: *Self) u64;
    pub const timeout = quic_endpoint_timeout;

    extern fn quic_endpoint_on_timeout(self: *Self) u64;
    pub const onTimeout = quic_endpoint_on_timeout;
};

pub const TransportHandler = extern struct {
    on_conn_created: ?*const fn (ctx: *anyopaque, conn: *Connection) callconv(.C) void,
    on_conn_established: ?*const fn (ctx: *anyopaque, conn: *Connection) callconv(.C) void,
    on_conn_closed: ?*const fn (ctx: *anyopaque, conn: *Connection) callconv(.C) void,
    on_stream_created: ?*const fn (ctx: *anyopaque, conn: *Connection, stream_id: u64) callconv(.C) void,
    on_stream_readable: ?*const fn (ctx: *anyopaque, conn: *Connection, stream_id: u64) callconv(.C) void,
    on_stream_writable: ?*const fn (ctx: *anyopaque, conn: *Connection, stream_id: u64) callconv(.C) void,
    on_stream_closed: ?*const fn (ctx: *anyopaque, conn: *Connection, stream_id: u64) callconv(.C) void,
    on_new_token: ?*const fn (ctx: *anyopaque, conn: *Connection, token: [*:0]const u8, token_len: usize) callconv(.C) void,
};

pub const IoVec = extern struct {
    iov_base: *anyopaque,
    iov_len: usize,
};

pub const PacketSendHandler = extern struct {
    on_packets_send: ?*const fn (ctx: *anyopaque, pkts: *PacketOutSpec, count: usize) callconv(.C) ?*isize,
};

test "SelectMethods" {
    var config = try Config.init();
    defer config.deinit();

    var tls_config = try TlsConfig.initServer(
        "cert.crt",
        "cert.key",
        .{ .http09 = true },
        true,
    );

    defer tls_config.deinit();
}
