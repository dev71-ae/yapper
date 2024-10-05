const std = @import("std");
const xev = @import("xev");

const c = @cImport({
    @cInclude("tquic.h");
});

const Server = struct {
    sock: usize = undefined,
    tls_config: *c.quic_tls_config_t = undefined,
};

pub fn main() !void {
    var loop = try xev.Loop.init(.{});
    defer loop.deinit();

    const w = try xev.Timer.init();
    defer w.deinit();

    c.quic_set_logger(@ptrCast(&debug_print), c.NULL, "TRACE");

    var server = Server{};

    const quic_config = c.quic_config_new();
    defer c.quic_config_free(quic_config);

    c.quic_config_set_max_idle_timeout(quic_config, 5000);
    c.quic_config_set_recv_udp_payload_size(quic_config, 1200);

    const protos: [1][]const u8 = .{"http/0.9"};

    const tls_quic_config = c.quic_tls_config_new_server_config("cert.crt", "cert.key", @ptrCast(&protos), 1, true);
    defer c.quic_tls_config_free(tls_quic_config);

    server.tls_config = tls_quic_config.?;

    c.quic_config_set_tls_selector(quic_config, &.{
        .get_default = get_default_tls_config,
        .select = select_tls_config,
    }, @ptrCast(&server));

    const quic_endpoint = c.quic_endpoint_new(quic_config, true, &.{
        .on_conn_created = server_on_conn_created,
        .on_conn_established = server_on_conn_established,
        .on_conn_closed = server_on_conn_closed,
        .on_stream_created = server_on_stream_created,
        .on_stream_readable = server_on_stream_readable,
        .on_stream_writable = server_on_stream_writable,
        .on_stream_closed = server_on_stream_closed,
    }, &server, &.{ .on_packets_send = server_on_packets_send }, &server);
    defer c.quic_endpoint_free(quic_endpoint);

    try loop.run(.until_done);
}

fn debug_print(data: [*c]u8, data_len: usize, argp: ?*anyopaque) callconv(.C) void {
    _ = data_len;
    _ = argp;

    std.debug.print("{s}", .{data});
}

fn get_default_tls_config(ctx: ?*anyopaque) callconv(.C) ?*c.struct_quic_tls_config_t {
    const server = opaqPtrTo(ctx, *Server);

    return server.tls_config;
}

fn select_tls_config(ctx: ?*anyopaque, server_name: [*c]const u8, server_name_len: usize) callconv(.C) ?*c.quic_tls_config_t {
    _ = server_name;
    _ = server_name_len;

    const server = opaqPtrTo(ctx, *Server);
    return server.tls_config;
}

fn server_on_conn_created(ctx: ?*anyopaque, conn: ?*c.quic_conn_t) callconv(.C) void {
    _ = ctx;
    _ = conn;

    std.debug.print("new ocaml my camel connection", .{});
}

fn server_on_conn_established(ctx: ?*anyopaque, conn: ?*c.quic_conn_t) callconv(.C) void {
    _ = ctx;
    _ = conn;

    std.debug.print("new ocaml my camel established", .{});
}

fn server_on_conn_closed(ctx: ?*anyopaque, conn: ?*c.quic_conn_t) callconv(.C) void {
    _ = ctx;
    _ = conn;

    std.debug.print("new ocaml my camel connection", .{});
}

fn server_on_stream_created(ctx: ?*anyopaque, conn: ?*c.quic_conn_t, stream_id: u64) callconv(.C) void {
    _ = ctx;
    _ = conn;

    std.debug.print("stream created {}", .{stream_id});
}

fn server_on_stream_readable(ctx: ?*anyopaque, conn: ?*c.quic_conn_t, stream_id: u64) callconv(.C) void {
    _ = ctx;

    var buf: [4096]u8 = undefined;
    var fin = false;

    const res = c.quic_stream_read(conn, stream_id, &buf, 4096, &fin);

    std.debug.print("got request", .{});
    std.debug.print("{}, {s}", .{ res, buf });

    if (fin) {
        const resp = "HTTP/0.9 200 OK\n";
        _ = c.quic_stream_write(conn, stream_id, resp, resp.len, true);
    }
}

fn server_on_stream_writable(ctx: ?*anyopaque, conn: ?*c.quic_conn_t, stream_id: u64) callconv(.C) void {
    _ = ctx;

    _ = c.quic_stream_wantwrite(conn, stream_id, false);
}

fn server_on_stream_closed(ctx: ?*anyopaque, conn: ?*c.quic_conn_t, stream_id: u64) callconv(.C) void {
    _ = ctx;
    _ = conn;

    std.debug.print("stream closed {}", .{stream_id});
}

fn server_on_packets_send(ctx: ?*anyopaque, pkts: [*c]c.quic_packet_out_spec_t, count: c_uint) callconv(.C) c_int {
    const server = opaqPtrTo(ctx, *Server);

    _ = server;
    _ = pkts;
    _ = count;

    return -1;
}

pub fn opaqPtrTo(ptr: ?*anyopaque, comptime T: type) T {
    return @ptrCast(@alignCast(ptr));
}
