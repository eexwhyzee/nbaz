const std = @import("std");

pub const Value = std.json.Value;

pub fn valueToString(v: Value) []const u8 {
    return switch (v) {
        .string => |s| s,
        else => "",
    };
}

pub fn valueToInt(v: Value) i64 {
    return switch (v) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        .string => |s| std.fmt.parseInt(i64, s, 10) catch 0,
        .bool => |b| if (b) 1 else 0,
        else => 0,
    };
}

pub fn valueToFloat(v: Value) f64 {
    return switch (v) {
        .float => |f| f,
        .integer => |i| @as(f64, @floatFromInt(i)),
        .string => |s| std.fmt.parseFloat(f64, s) catch 0.0,
        .bool => |b| if (b) 1.0 else 0.0,
        else => 0.0,
    };
}

pub fn valueToBool(v: Value) bool {
    return switch (v) {
        .bool => |b| b,
        .integer => |i| i != 0,
        .float => |f| f != 0.0,
        .string => |s| std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "1"),
        else => false,
    };
}

pub fn getString(obj: std.json.ObjectMap, key: []const u8, default: []const u8) []const u8 {
    if (obj.get(key)) |v| return valueToString(v);
    return default;
}

pub fn getInt(obj: std.json.ObjectMap, key: []const u8, default: i64) i64 {
    if (obj.get(key)) |v| return valueToInt(v);
    return default;
}

pub fn getFloat(obj: std.json.ObjectMap, key: []const u8, default: f64) f64 {
    if (obj.get(key)) |v| return valueToFloat(v);
    return default;
}

pub fn getBool(obj: std.json.ObjectMap, key: []const u8, default: bool) bool {
    if (obj.get(key)) |v| return valueToBool(v);
    return default;
}
