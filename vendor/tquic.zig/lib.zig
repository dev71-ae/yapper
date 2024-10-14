//! A Zig wrapper for TQuic (https://tquic.net)
//! STATUS: Incomplete

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

inline fn cast(comptime T: type, v: ?*const anyopaque) *const T {
    return @as(*const T, @ptrCast(@alignCast(v)));
}

/// Configurations about QUIC endpoint.
pub const Config = opaque {
    const Self = Config;

    /// Create default configuration.
    /// The caller is responsible for the memory of the Config and should properly
    /// destroy it by calling `deinit`.
    pub inline fn init() !*Self {
        return quic_config_new() orelse error.TQuicError;
    }

    extern fn quic_config_new() ?*Self;

    /// Destroy a Config instance.
    pub const deinit = quic_config_free;
    extern fn quic_config_free(self: *Self) void;

    // Set the `max_idle_timeout` transport parameter in milliseconds.
    pub const setMaxIdleTimeout = quic_config_set_max_idle_timeout;
    extern fn quic_config_set_max_idle_timeout(self: *Self, length: u64) void;

    /// Set handshake timeout in milliseconds. Zero turns the timeout off.
    pub const setRecvUpdPlayloadSize = quic_config_set_recv_udp_payload_size;
    extern fn quic_config_set_recv_udp_payload_size(self: *Self, size: u16) void;

    /// Set TLS config selector.
    pub inline fn setTlsSelector(
        self: *Self,
        comptime T: type,
        context: T,
        methods: struct {
            get_default: fn (ctx: *const T) *TlsConfig,
            select: fn (ctx: *const T, server_name: [*:0]const u8, server_name_len: usize) *TlsConfig,
        },
    ) void {
        const wrapper = struct {
            fn getDefault(ctx: *anyopaque) callconv(.C) void {
                @call(.always_inline, methods.get_default, .{cast(T, ctx)});
            }

            fn select(
                ctx: *anyopaque,
                server_name: [*:0]const u8,
                server_name_len: usize,
            ) callconv(.C) void {
                @call(.always_inline, methods.select, .{ cast(T, ctx), server_name, server_name_len });
            }
        };

        quic_config_set_tls_selector(
            self,
            .{
                .get_default = wrapper.getDefault,
                .select = wrapper.select,
            },
            context,
        );
    }

    extern fn quic_config_set_tls_selector(
        self: *Self,
        methods: *const TlsConfig.SelectMethods,
        context: *anyopaque,
    ) void;
};

pub const TlsConfig = opaque {
    const Self = TlsConfig;

    pub const SelectMethods = extern struct {
        pub const TlsConfigSelectorContext = opaque {};

        get_default: *const fn (*TlsConfigSelectorContext) callconv(.C) *Self,
        select: *const fn (
            *TlsConfigSelectorContext,
            [*:0]const u8,
            usize,
        ) callconv(.C) *Self,
    };

    /// Create a new server side TlsConfig.
    /// The caller is responsible for the memory of the TlsConfig and should properly
    /// destroy it by calling `deinit`.
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

    extern fn quic_tls_config_new_server_config(
        cert_file: [*:0]const u8,
        key_file: [*:0]const u8,
        protos: [*]const [*:0]const u8,
        proto_num: isize,
        enable_early_data: bool,
    ) ?*Self;

    /// Destroy a TlsConfig instance.
    pub const deinit = quic_tls_config_free;
    extern fn quic_tls_config_free(tls_config: *Self) void;
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

    /// Set logger.
    pub inline fn setLogger(
        comptime T: type,
        argp: T,
        cb: fn (data: []const u8, data_len: usize, argp: T) void,
        level: Level,
    ) void {
        quic_set_logger(struct {
            fn wrapper(data: [*:0]const u8, data_len: usize, argp_: ?*anyopaque) callconv(.C) void {
                @call(.always_inline, cb, .{ data, data_len, cast(T, argp_) });
            }
        }.wrapper, @ptrCast(argp), level.to_slice());
    }

    extern fn quic_set_logger(
        cb: fn ([*:0]const u8, usize, ?*anyopaque) callconv(.C) void,
        argp: ?*anyopaque,
        level: [*:0]const u8,
    ) void;
};

pub const Connection = opaque {};

/// Meta information of an incoming packet.
pub const PacketInfo = extern struct {
    src: *const posix.sockaddr,
    src_len: posix.socklen_t,
    dst: *const posix.sockaddr,
    dst_len: posix.socklen_t,
};

/// Data and meta information of an outgoing packet.
pub const PacketOutSpec = extern struct {
    iov: [*]const posix.iovec,
    iovlen: usize,
    src_addr: ?*const anyopaque,
    src_addr_len: posix.socklen_t,
    dst_addr: ?*const anyopaque,
    dst_addr_len: posix.socklen_t,
};

pub const Endpoint = opaque {
    const Self = Endpoint;

    /// Create a QUIC endpoint.
    ///
    /// The caller is responsible for the memory of the Endpoint and properly
    /// destroy it by calling `deinit`.
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

    extern fn quic_endpoint_new(
        config: *Config,
        is_server: bool,
        handler_methods: *const TransportHandler,
        handler_ctx: *anyopaque,
        sender_methods: *const PacketSendHandler,
        sender_ctx: *anyopaque,
    ) ?*Self;

    /// Destroy a QUIC endpoint.
    pub const deinit = quic_endpoint_free;
    extern fn quic_endpoint_free(endpoint: *Self) void;

    /// Process internal events of all tickable connections.
    pub const processConnections = quic_endpoint_process_connections;
    extern fn quic_endpoint_process_connections(endpoint: *Self) c_int;

    /// Process an incoming UDP datagram.
    pub const recv = quic_endpoint_recv;
    extern fn quic_endpoint_recv(
        endpoint: *Self,
        buf: [*]u8,
        buf_len: usize,
        info: *const PacketInfo,
    ) c_int;

    /// Return the amount of time until the next timeout event.
    pub const timeout = quic_endpoint_timeout;
    extern fn quic_endpoint_timeout(self: *const Self) u64;

    /// Process timeout events on the endpoint.
    pub const onTimeout = quic_endpoint_on_timeout;
    extern fn quic_endpoint_on_timeout(self: *Self) u64;
};

/// The TransportHandler lists the callbacks used by the endpoint to
/// communicate with the user application code.
pub const TransportHandler = extern struct {
    /// Called when a new connection has been created. This callback is called
    /// as soon as connection object is created inside the endpoint, but
    /// before the handshake is done. The connection has progressed enough to
    /// send early data if possible.
    on_conn_created: ?*const fn (ctx: *anyopaque, conn: *Connection) callconv(.C) void,

    /// Called when the handshake is completed.
    on_conn_established: ?*const fn (ctx: *anyopaque, conn: *Connection) callconv(.C) void,

    /// Called when the connection is closed. The connection is no longer
    /// accessible after this callback returns. It is a good time to clean up
    /// the connection context.
    on_conn_closed: ?*const fn (ctx: *anyopaque, conn: *Connection) callconv(.C) void,

    /// Called when the stream is created.
    on_stream_created: ?*const fn (ctx: *anyopaque, conn: *Connection, stream_id: u64) callconv(.C) void,

    /// Called when the stream is readable. This callback is called when either
    /// there are bytes to be read or an error is ready to be collected.
    on_stream_readable: ?*const fn (ctx: *anyopaque, conn: *Connection, stream_id: u64) callconv(.C) void,

    /// Called when the stream is writable.
    on_stream_writable: ?*const fn (ctx: *anyopaque, conn: *Connection, stream_id: u64) callconv(.C) void,

    /// Called when the stream is closed. The stream is no longer accessible
    /// after this callback returns. It is a good time to clean up the stream
    /// context.
    on_stream_closed: ?*const fn (ctx: *anyopaque, conn: *Connection, stream_id: u64) callconv(.C) void,

    /// Called when client receives a token in NEW_TOKEN frame.
    on_new_token: ?*const fn (
        ctx: *anyopaque,
        conn: *Connection,
        token: [*:0]const u8,
        token_len: usize,
    ) callconv(.C) void,
};

/// The PacketSendHandler lists the callbacks used by the endpoint to
/// send packet out.
pub const PacketSendHandler = extern struct {
    /// Called when the connection is sending packets out.
    ///
    /// On success, `on_packets_send()` returns the number of messages sent. If
    /// this is less than `pkts.len()`, the connection will retry with a further
    /// `on_packets_send()` call to send the remaining messages.
    on_packets_send: ?*const fn (ctx: *anyopaque, pkts: *PacketOutSpec, count: usize) callconv(.C) ?*isize,
};
