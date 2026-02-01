const std = @import("std");

test {
    _ = @import("util/date.zig");
    _ = @import("model/scoreboard.zig");
    _ = @import("model/playbyplay.zig");
    _ = @import("model/boxscore.zig");
}

pub fn main() void {}
