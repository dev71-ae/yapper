const std = @import("std");
const builtin = @import("builtin");

const net = std.net;
const posix = std.posix;

const xev = @import("xev");
const tquic = @import("tquic");

const Config = struct {
    pub const addr = "127.0.0.1";
    pub const port = 3000;

    pub const read_buf_len = 4096;
    pub const payload_size = 1200;
    pub const max_idle_timeout = 5000;
};

fn log_stdout(data: []const u8, _: ?*const void) void {
    const log = std.log.scoped(.TQuic);
    log.info("{s}", .{data});
}

pub fn main() !void {
    tquic.setLogger(void, null, log_stdout, .Trace);

    var quic_config = try tquic.Config.init();
    defer quic_config.deinit();

    quic_config.setMaxIdleTimeout(Config.max_idle_timeout);
    quic_config.setRecvUpdPlayloadSize(Config.payload_size);

    const quic_tls_config = try tquic.TlsConfig.initServer(
        "cert.crt",
        "cert.key",
        .{ .h3 = true },
        true,
    );

    defer quic_tls_config.deinit();

    const addr = try net.Address.parseIp(Config.addr, Config.port);
    var server = try Server.init(addr, quic_config, quic_tls_config);
    defer server.deinit();

    quic_config.setTlsSelector(Server, &server, .{
        .get_default = Server.get_default_tls_config,
        .select = Server.select_tls_config,
    });

    var loop = try xev.Loop.init(.{ .entries = 1024 });
    defer loop.deinit();

    try server.start(&loop);

    try loop.run(.until_done);
}

const Server = struct {
    udp: xev.UDP,
    addr: std.net.Address,
    timer: xev.Timer,

    read_buf: [Config.read_buf_len]u8 = undefined,

    c_read: xev.Completion = undefined,
    c_timer: xev.Completion = undefined,

    state_read: xev.UDP.State = undefined,
    state_timer: xev.UDP.State = undefined,

    // Quic
    tls_config: *tquic.TlsConfig,
    endpoint: *tquic.Endpoint,

    const Self = Server;

    pub fn init(
        addr: net.Address,
        quic_config: *tquic.Config,
        quic_tls_config: *tquic.TlsConfig,
    ) !Self {
        var self: Self = .{
            .udp = try xev.UDP.init(addr),
            .addr = addr,
            .tls_config = quic_tls_config,
            .endpoint = undefined,
            .timer = try xev.Timer.init(),
        };

        self.endpoint = try tquic.Endpoint.init(quic_config, true, &.{
            .on_conn_created = server_on_conn_created,
            .on_conn_established = server_on_conn_established,
            .on_conn_closed = server_on_conn_closed,
            .on_stream_created = server_on_stream_created,
            .on_stream_readable = null,
            .on_stream_writable = null,
            .on_stream_closed = null,
            .on_new_token = null,
        }, &self, &.{
            .on_packets_send = null,
        }, &self);

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.endpoint.deinit();
        self.timer.deinit();
    }

    pub fn start(self: *Self, loop: *xev.Loop) !void {
        try self.udp.bind(self.addr);

        self.udp.read(
            loop,
            &self.c_read,
            &self.state_read,
            .{ .slice = &self.read_buf },
            Server,
            self,
            readCallBack,
        );

        _ = self.endpoint.processConnections();
    }

    fn readCallBack(
        self_: ?*Self,
        _: *xev.Loop,
        _: *xev.Completion,
        _: *xev.UDP.State,
        remote_addr: std.net.Address,
        _: xev.UDP,
        buf: xev.ReadBuffer,
        _: xev.UDP.ReadError!usize,
    ) xev.CallbackAction {
        const self = self_.?;

        std.debug.print("{any}", .{remote_addr});

        const r = self.endpoint.recv(buf.slice.ptr, buf.slice.len, &.{
            .src = &remote_addr.any,
            .src_len = remote_addr.getOsSockLen(),
            .dst = &self.addr.any,
            .dst_len = self.addr.getOsSockLen(),
        });

        if (r != 0) {
            std.debug.print("recv failed {}\n", .{r});
        }

        return .rearm;
    }

    fn timerCallback(
        self_: ?*Self,
        _: *xev.Loop,
        _: *xev.Completion,
        _: xev.Timer.RunError!void,
    ) xev.CallbackAction {
        const self = self_.?;

        self.endpoint.on_timeout();
        self.endpoint.process_connections();

        return .rearm;
    }

    fn get_default_tls_config(ctx: *const Server) *tquic.TlsConfig {
        return ctx.tls_config;
    }

    fn select_tls_config(ctx: *const Server, _: []const u8) *tquic.TlsConfig {
        return ctx.tls_config;
    }

    fn server_on_conn_created(_: *anyopaque, _: *tquic.Connection) callconv(.C) void {
        std.debug.print("new ocaml my camel connection", .{});
    }

    fn server_on_conn_established(_: *anyopaque, _: *tquic.Connection) callconv(.C) void {
        std.debug.print("new ocaml my camel established", .{});
    }

    fn server_on_conn_closed(_: *anyopaque, _: *tquic.Connection) callconv(.C) void {
        std.debug.print("new ocaml my camel connection", .{});
    }

    fn server_on_stream_created(_: *anyopaque, _: *tquic.Connection, stream_id: u64) callconv(.C) void {
        std.debug.print("stream created {}", .{stream_id});
    }
};
