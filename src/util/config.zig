const std = @import("std");

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Config = struct {
    base_url: []const u8,
    core_base_url: []const u8,
    headers: []Header,
};

pub const Overrides = struct {
    allocator: std.mem.Allocator,
    base_url: ?[]const u8 = null,
    core_base_url: ?[]const u8 = null,
    headers: std.ArrayList(Header),

    pub fn init(allocator: std.mem.Allocator) Overrides {
        return .{ .allocator = allocator, .headers = std.ArrayList(Header).empty };
    }

    pub fn deinit(self: *Overrides) void {
        self.headers.deinit(self.allocator);
    }
};

const default_base_url = "https://cdn.nba.com/static/json/liveData";
const default_core_base_url = "https://core-api.nba.com";

pub fn load(allocator: std.mem.Allocator) !Config {
    var headers = std.ArrayList(Header).empty;

    var base_url: []const u8 = default_base_url;
    var core_base_url: []const u8 = default_core_base_url;

    // Load config file if present.
    if (try readConfigFile(allocator)) |file_cfg| {
        if (file_cfg.base_url) |v| base_url = v;
        if (file_cfg.core_base_url) |v| core_base_url = v;
        for (file_cfg.headers) |h| {
            try headers.append(allocator, h);
        }
    }

    // Environment overrides.
    if (std.process.getEnvVarOwned(allocator, "NBA_BASE_URL")) |env_base| {
        base_url = env_base;
    } else |_| {}

    if (std.process.getEnvVarOwned(allocator, "NBA_CORE_BASE_URL")) |env_core| {
        core_base_url = env_core;
    } else |_| {}

    if (std.process.getEnvVarOwned(allocator, "NBA_HEADERS")) |env_headers| {
        defer allocator.free(env_headers);
        try parseHeadersEnv(allocator, &headers, env_headers);
    } else |_| {}

    return .{
        .base_url = base_url,
        .core_base_url = core_base_url,
        .headers = try headers.toOwnedSlice(allocator),
    };
}

pub fn applyOverrides(allocator: std.mem.Allocator, cfg: Config, overrides: *Overrides) !Config {
    var headers = std.ArrayList(Header).empty;
    for (cfg.headers) |h| try headers.append(allocator, h);
    for (overrides.headers.items) |h| try headers.append(allocator, h);

    return .{
        .base_url = overrides.base_url orelse cfg.base_url,
        .core_base_url = overrides.core_base_url orelse cfg.core_base_url,
        .headers = try headers.toOwnedSlice(allocator),
    };
}

const FileConfig = struct {
    base_url: ?[]const u8,
    core_base_url: ?[]const u8,
    headers: []Header,
};

fn readConfigFile(allocator: std.mem.Allocator) !?FileConfig {
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch return null;
    defer allocator.free(home);

    var path_buf = std.ArrayList(u8).empty;
    defer path_buf.deinit(allocator);
    try path_buf.appendSlice(allocator, home);
    try path_buf.appendSlice(allocator, "/.config/nbaz/config.json");

    const path = path_buf.items;
    const file = std.fs.openFileAbsolute(path, .{}) catch return null;
    defer file.close();

    const stat = try file.stat();
    const size = @min(stat.size, 5 * 1024 * 1024);
    var buffer = try allocator.alloc(u8, size);
    defer allocator.free(buffer);
    const read_len = try file.readAll(buffer);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, buffer[0..read_len], .{});
    defer parsed.deinit();

    if (parsed.value != .object) return null;
    const obj = parsed.value.object;

    var headers = std.ArrayList(Header).empty;

    var base_url: ?[]const u8 = null;
    var core_base_url: ?[]const u8 = null;

    if (obj.get("base_url")) |v| {
        if (v == .string) base_url = try allocator.dupe(u8, v.string);
    }
    if (obj.get("core_base_url")) |v| {
        if (v == .string) core_base_url = try allocator.dupe(u8, v.string);
    }
    if (obj.get("headers")) |v| {
        if (v == .object) {
            var it = v.object.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == .string) {
                    const name_copy = try allocator.dupe(u8, entry.key_ptr.*);
                    const value_copy = try allocator.dupe(u8, entry.value_ptr.*.string);
                    try headers.append(allocator, .{ .name = name_copy, .value = value_copy });
                }
            }
        }
    }

    return .{
        .base_url = base_url,
        .core_base_url = core_base_url,
        .headers = try headers.toOwnedSlice(allocator),
    };
}

fn parseHeadersEnv(allocator: std.mem.Allocator, headers: *std.ArrayList(Header), raw: []const u8) !void {
    var parts = splitHeaders(raw);
    while (parts.next()) |item| {
        if (item.len == 0) continue;
        if (parseHeaderLine(allocator, item)) |h| {
            try headers.append(allocator, h);
        }
    }
}

fn splitHeaders(raw: []const u8) std.mem.SplitIterator(u8, .any) {
    return std.mem.splitAny(u8, raw, ";,\n");
}

pub fn parseHeaderLine(allocator: std.mem.Allocator, line: []const u8) ?Header {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return null;
    const colon = std.mem.indexOfScalar(u8, trimmed, ':') orelse return null;
    const name = std.mem.trim(u8, trimmed[0..colon], " \t");
    const value = std.mem.trim(u8, trimmed[colon + 1 ..], " \t");
    if (name.len == 0 or value.len == 0) return null;

    const name_copy = allocator.dupe(u8, name) catch return null;
    const value_copy = allocator.dupe(u8, value) catch return null;
    return .{ .name = name_copy, .value = value_copy };
}
