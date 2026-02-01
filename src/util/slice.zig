const std = @import("std");

pub fn sliceContains(slice: []const []const u8, val: []const u8) bool {
    for (slice) |item| {
        if (std.mem.eql(u8, item, val)) return true;
    }
    return false;
}

test "sliceContains" {
    const vals = [_][]const u8{ "a", "b", "c" };
    try std.testing.expect(sliceContains(vals[0..], "b"));
    try std.testing.expect(!sliceContains(vals[0..], "d"));
}
