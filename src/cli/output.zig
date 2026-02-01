const std = @import("std");
const scoreboard = @import("../model/scoreboard.zig");

pub const Format = enum { json, table };

pub const OutputError = error{InvalidFormat};

pub fn parseFormat(value: []const u8) OutputError!Format {
    if (std.mem.eql(u8, value, "json")) return .json;
    if (std.mem.eql(u8, value, "table")) return .table;
    return error.InvalidFormat;
}

pub fn printJson(value: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var out = std.fs.File.stdout().writer(&buffer);
    try std.json.Stringify.value(value, .{ .whitespace = .indent_2 }, &out.interface);
    try out.interface.writeByte('\n');
}

pub fn printScoreboardTable(sb: scoreboard.ScoreBoard) !void {
    var buffer: [4096]u8 = undefined;
    var out = std.fs.File.stdout().writer(&buffer);
    try out.interface.writeAll("GAME ID   AWAY HOME SCORE  STATUS       PERIOD CLOCK\n");
    for (sb.scoreboard.games) |g| {
        const away = g.awayTeam.teamTricode;
        const home = g.homeTeam.teamTricode;
        const away_score = g.awayTeam.score;
        const home_score = g.homeTeam.score;
        try out.interface.print("{s:<8} {s:<4} {s:<4} {d:>3}-{d:<3} {s:<12} {d:>2} {s:<5}\n", .{
            g.gameId,
            away,
            home,
            away_score,
            home_score,
            g.gameStatusText,
            g.period,
            g.gameClock,
        });
    }
}
