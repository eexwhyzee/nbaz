const std = @import("std");

pub fn roundFloat(value: f64, precision: u32) f64 {
    const pow10 = std.math.pow(f64, 10.0, @as(f64, @floatFromInt(precision)));
    const scaled = value * pow10;
    const rounded = if (scaled >= 0) std.math.floor(scaled + 0.5) else std.math.ceil(scaled - 0.5);
    return rounded / pow10;
}

test "roundFloat" {
    try std.testing.expectEqual(@as(f64, 1.2), roundFloat(1.23, 1));
    try std.testing.expectEqual(@as(f64, 1.23), roundFloat(1.234, 2));
    try std.testing.expectEqual(@as(f64, 0.0), roundFloat(0.0, 3));
}
