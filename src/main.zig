const std = @import("std");
const args = @import("cli/args.zig");
const output = @import("cli/output.zig");
const config_mod = @import("util/config.zig");
const nba = @import("client/nba.zig");
const boxscore = @import("model/boxscore.zig");
const playbyplay = @import("model/playbyplay.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var overrides = config_mod.Overrides.init(allocator);
    defer overrides.deinit();

    var format: output.Format = .json;
    var cmd_name: ?[]const u8 = null;
    var cmd_args = std.ArrayList([]const u8).empty;
    defer cmd_args.deinit(allocator);

    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();
    _ = it.next();

    while (it.next()) |arg| {
        if (cmd_name == null and std.mem.startsWith(u8, arg, "--")) {
            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                try printUsage();
                return;
            } else if (std.mem.eql(u8, arg, "--format")) {
                const value = it.next() orelse return error.MissingFormat;
                format = try output.parseFormat(value);
            } else if (std.mem.eql(u8, arg, "--base-url")) {
                const value = it.next() orelse return error.MissingBaseUrl;
                overrides.base_url = value;
            } else if (std.mem.eql(u8, arg, "--core-base-url")) {
                const value = it.next() orelse return error.MissingCoreBaseUrl;
                overrides.core_base_url = value;
            } else if (std.mem.eql(u8, arg, "--header")) {
                const value = it.next() orelse return error.MissingHeader;
                if (config_mod.parseHeaderLine(allocator, value)) |h| {
                    try overrides.headers.append(allocator, h);
                }
            } else {
                return error.UnknownOption;
            }
        } else {
            if (cmd_name == null) {
                cmd_name = arg;
            } else {
                try cmd_args.append(allocator, arg);
            }
        }
    }

    if (cmd_name == null) {
        try printUsage();
        return;
    }

    const base_cfg = try config_mod.load(allocator);
    const cfg = try config_mod.applyOverrides(allocator, base_cfg, &overrides);

    const command = cmd_name.?;
    if (std.mem.eql(u8, command, "scoreboard")) {
        const date = try args.requireOption(cmd_args.items, "--date");
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const sb = try nba.fetchScoreboard(arena.allocator(), cfg, date);
        switch (format) {
            .json => try output.printJson(sb),
            .table => try output.printScoreboardTable(sb),
        }
        return;
    }

    if (std.mem.eql(u8, command, "boxscore")) {
        const game_id = try args.requireOption(cmd_args.items, "--game-id");
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const bs = try nba.fetchBoxScore(arena.allocator(), cfg, game_id);
        if (format == .table) return error.UnsupportedFormat;
        try output.printJson(bs);
        return;
    }

    if (std.mem.eql(u8, command, "playbyplay")) {
        const game_id = try args.requireOption(cmd_args.items, "--game-id");
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const pbp = try nba.fetchPlayByPlay(arena.allocator(), cfg, game_id);
        if (format == .table) return error.UnsupportedFormat;
        try output.printJson(pbp);
        return;
    }

    if (std.mem.eql(u8, command, "shotchart")) {
        const game_id = try args.requireOption(cmd_args.items, "--game-id");
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const bs = try nba.fetchBoxScore(arena.allocator(), cfg, game_id);
        const pbp = try nba.fetchPlayByPlay(arena.allocator(), cfg, game_id);
        const chart = try playbyplay.getShotChart(
            arena.allocator(),
            pbp,
            bs.game.homeTeam.teamId,
            bs.game.awayTeam.teamId,
        );
        if (format == .table) return error.UnsupportedFormat;
        try output.printJson(chart);
        return;
    }

    if (std.mem.eql(u8, command, "refs")) {
        const game_id = try args.requireOption(cmd_args.items, "--game-id");
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const bs = try nba.fetchBoxScore(arena.allocator(), cfg, game_id);
        const pbp = try nba.fetchPlayByPlay(arena.allocator(), cfg, game_id);
        const stats = try boxscore.getRefStats(arena.allocator(), bs, pbp);
        if (format == .table) return error.UnsupportedFormat;
        try output.printJson(stats);
        return;
    }

    return error.UnknownCommand;
}

fn printUsage() !void {
    var buffer: [4096]u8 = undefined;
    var out = std.fs.File.stderr().writer(&buffer);
    try out.interface.writeAll(
        "nbaz - NBA API CLI (Zig)\n\n" ++
        "Usage:\n" ++
        "  nbaz [global options] <command> [command options]\n\n" ++
        "Global options:\n" ++
        "  --format json|table       Output format (default: json)\n" ++
        "  --base-url URL            Override CDN base URL\n" ++
        "  --core-base-url URL       Override core API base URL\n" ++
        "  --header \"Key: Value\"     Add an extra HTTP header (repeatable)\n\n" ++
        "Commands:\n" ++
        "  scoreboard --date YYYYMMDD\n" ++
        "  boxscore --game-id GAME_ID\n" ++
        "  playbyplay --game-id GAME_ID\n" ++
        "  shotchart --game-id GAME_ID\n" ++
        "  refs --game-id GAME_ID\n",
    );
    try out.interface.flush();
}
