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

pub fn main() !void {
    tquic.Logger.set(.Trace);

    var quic_config = try tquic.Config.init();
    defer quic_config.deinit();

    quic_config.set_max_idle_timeout(Config.max_idle_timeout);
    quic_config.set_recv_udp_payload_size(Config.payload_size);

    var quic_tls_config = try tquic.TlsConfig.initServer(
        "cert.crt",
        "cert.key",
        .{ .interop = true },
        true,
    );
    defer quic_tls_config.deinit();

    const addr = try net.Address.parseIp(Config.addr, Config.port);
    var server = try Server.init(addr, quic_config, quic_tls_config);
    defer server.deinit();

    quic_config.set_tls_selector(server, .{
        .get_default = Server.get_default_tls_config,
        .select = Server.select_tls_config,
    });

    var loop = try xev.Loop.init(.{});
    defer loop.deinit();

    const w = try xev.Timer.init();
    defer w.deinit();

    try server.start(&loop);

    try loop.run(.until_done);
}

fn debug_print(data: [*c]u8, data_len: usize, argp: ?*anyopaque) callconv(.C) void {
    _ = data_len;
    _ = argp;

    std.debug.print("{s}", .{data});
}

fn opaqPtrTo(ptr: ?*anyopaque, comptime T: type) T {
    return @ptrCast(@alignCast(ptr));
}

const Server = struct {
    udp: xev.UDP,
    addr: std.net.Address,

    read_buf: [Config.read_buf_len]u8 = undefined,
    c_read: xev.Completion = undefined,
    c_write: xev.Completion = undefined,
    state_read: xev.UDP.State = undefined,
    state_write: xev.UDP.State = undefined,

    // Quic
    tls_config: tquic.TlsConfig,
    endpoint: tquic.TlsConfig,

    const Self = Server;

    pub fn init(
        addr: net.Address,
        _: tquic.Config,
        quic_tls_config: tquic.TlsConfig,
    ) !Self {
        const self: Self = .{
            .udp = try xev.UDP.init(addr),
            .addr = addr,
            .tls_config = quic_tls_config,
            .endpoint = undefined,
        };

        // const quic_endpoint = tquic.Endpoint.init(quic_config, true);
        // const quic_endpoint = tquic.c.quic_endpoint_new(quic_config.handle, true, &.{
        //     .on_conn_created = server_on_conn_created,
        //     .on_conn_established = server_on_conn_established,
        //     .on_conn_closed = server_on_conn_closed,
        //     .on_stream_created = server_on_stream_created,
        //     .on_stream_readable = server_on_stream_readable,
        //     .on_stream_writable = server_on_stream_writable,
        //     .on_stream_closed = server_on_stream_closed,
        // }, &self, &.{ .on_packets_send = server_on_packets_send }, &self);

        // self.endpoint = quic_endpoint orelse return error.CreateEndpoint;

        return self;
    }

    pub fn deinit(self: *Self) void {
        tquic.c.quic_endpoint_free(self.endpoint);
    }

    // pub fn start(self: *Self, loop: *xev.Loop) !void {
    //     try self.udp.bind(self.addr);

    //     self.udp.read(
    //         loop,
    //         &self.c_read,
    //         &self.state_read,
    //         .{ .slice = &self.read_buf },
    //         Server,
    //         self,
    //         readCallBack,
    //     );
    // }

    // fn readCallBack(
    //     self_: ?*Self,
    //     _: *xev.Loop,
    //     _: *xev.Completion,
    //     _: *xev.UDP.State,
    //     _: std.net.Address,
    //     socket: xev.UDP,
    //     buf: xev.ReadBuffer,
    //     _: xev.UDP.ReadError!usize,
    // ) xev.CallbackAction {
    //     const self = self_.?;

    //     _ = socket;
    //     while (true) {
    //         const sockaddr = self.addr.any;
    //         const quic_packet_info: tquic.c.quic_packet_info_t = .{
    //             .src = 0,
    //             .src_len = 0,
    //             .dst = &tquic.c.sockaddr{
    //                 .sa_family = sockaddr.family,
    //                 .sa_data = sockaddr.data,
    //                 .sa_len = sockaddr.data.len,
    //             },
    //             .dst_len = @intCast(self.addr.getOsSockLen()),
    //         };

    //         const recv = tquic.c.quic_endpoint_recv(self.endpoint, @ptrCast(buf.slice), buf.slice.len, &quic_packet_info);
    //         if (recv != 0) {
    //             @panic("recv fail");
    //         }
    //     }

    //     tquic.c.quic_endpoint_process_connections(@ptrCast(self.endpoint));
    //     return .rearm;
    // }

    fn get_default_tls_config(ctx: ?*anyopaque) callconv(.C) ?*tquic.c.struct_quic_tls_config_t {
        const server = opaqPtrTo(ctx, *Server);
        return server.tls_config;
    }

    fn select_tls_config(ctx: ?*anyopaque, _: [*c]const u8, _: usize) callconv(.C) ?*tquic.c.quic_tls_config_t {
        const server = opaqPtrTo(ctx, *Server);
        return server.tls_config;
    }

    // fn server_on_conn_created(_: ?*anyopaque, _: ?*tquic.c.quic_conn_t) callconv(.C) void {
    //     std.debug.print("new ocaml my camel connection", .{});
    // }

    // fn server_on_conn_established(_: ?*anyopaque, _: ?*tquic.c.quic_conn_t) callconv(.C) void {
    //     std.debug.print("new ocaml my camel established", .{});
    // }

    // fn server_on_conn_closed(_: ?*anyopaque, _: ?*tquic.c.quic_conn_t) callconv(.C) void {
    //     std.debug.print("new ocaml my camel connection", .{});
    // }

    // fn server_on_stream_created(_: ?*anyopaque, _: ?*tquic.c.quic_conn_t, stream_id: u64) callconv(.C) void {
    //     std.debug.print("stream created {}", .{stream_id});
    // }

    // fn server_on_stream_readable(_: ?*anyopaque, conn: ?*tquic.c.quic_conn_t, stream_id: u64) callconv(.C) void {
    //     var buf: [4096]u8 = undefined;
    //     var fin = false;

    //     const res = tquic.c.quic_stream_read(conn, stream_id, &buf, 4096, &fin);

    //     std.debug.print("got request", .{});
    //     std.debug.print("{}, {s}", .{ res, buf });

    //     if (fin) {
    //         const resp = "HTTP/0.9 200 OK\n";
    //         _ = tquic.c.quic_stream_write(conn, stream_id, resp, resp.len, true);
    //     }
    // }

    // fn server_on_stream_writable(_: ?*anyopaque, conn: ?*tquic.c.quic_conn_t, stream_id: u64) callconv(.C) void {
    //     _ = tquic.c.quic_stream_wantwrite(conn, stream_id, false);
    // }

    // fn server_on_stream_closed(_: ?*anyopaque, _: ?*tquic.c.quic_conn_t, stream_id: u64) callconv(.C) void {
    //     std.debug.print("stream closed {}", .{stream_id});
    // }

    // fn server_on_packets_send(ctx: ?*anyopaque, pkts: [*c]tquic.c.quic_packet_out_spec_t, count: c_uint) callconv(.C) c_int {
    //     const server = opaqPtrTo(ctx, *Server);

    //     _ = server;
    //     _ = pkts;
    //     _ = count;

    //     return -1;
    // }
};
