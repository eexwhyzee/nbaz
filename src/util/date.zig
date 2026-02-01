const std = @import("std");

pub const DateError = error{InvalidDate} || std.mem.Allocator.Error;

pub fn convertDateFormat(allocator: std.mem.Allocator, date: []const u8) DateError![]const u8 {
    if (date.len != 8) return error.InvalidDate;
    if (!std.ascii.isDigit(date[0]) or !std.ascii.isDigit(date[1]) or !std.ascii.isDigit(date[2]) or !std.ascii.isDigit(date[3]) or
        !std.ascii.isDigit(date[4]) or !std.ascii.isDigit(date[5]) or !std.ascii.isDigit(date[6]) or !std.ascii.isDigit(date[7]))
    {
        return error.InvalidDate;
    }

    var out = try allocator.alloc(u8, 10);
    out[0] = date[4];
    out[1] = date[5];
    out[2] = '/';
    out[3] = date[6];
    out[4] = date[7];
    out[5] = '/';
    out[6] = date[0];
    out[7] = date[1];
    out[8] = date[2];
    out[9] = date[3];
    return out;
}

test "convertDateFormat" {
    const allocator = std.testing.allocator;
    const out = try convertDateFormat(allocator, "20231105");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("11/05/2023", out);

    try std.testing.expectError(error.InvalidDate, convertDateFormat(allocator, "2023-11-05"));
}
