const std = @import("std");
const config = @import("../util/config.zig");

pub const HttpError = error{BadStatus, InvalidUrl} || std.http.Client.FetchError;

pub fn get(allocator: std.mem.Allocator, url: []const u8, headers: []const config.Header) HttpError![]u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var http_headers = try allocator.alloc(std.http.Header, headers.len);
    defer allocator.free(http_headers);
    for (headers, 0..) |h, i| {
        http_headers[i] = .{ .name = h.name, .value = h.value };
    }

    var out: std.io.Writer.Allocating = .init(allocator);
    defer out.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = http_headers,
        .response_writer = &out.writer,
    });

    if (result.status != .ok) return error.BadStatus;
    return try out.toOwnedSlice();
}
