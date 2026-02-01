const std = @import("std");
const http = @import("http.zig");
const config_mod = @import("../util/config.zig");
const date_util = @import("../util/date.zig");
const scoreboard = @import("../model/scoreboard.zig");
const boxscore = @import("../model/boxscore.zig");
const playbyplay = @import("../model/playbyplay.zig");

// Note: copied this scoreboard_key from nba.com, it's required for
// the gamecardfeed
const scoreboard_key = "747fa6900c6c4e89a58b81b72f36eb96";

pub fn fetchScoreboard(allocator: std.mem.Allocator, cfg: config_mod.Config, date: []const u8) !scoreboard.ScoreBoard {
    const converted = try date_util.convertDateFormat(allocator, date);

    var url_buf = std.ArrayList(u8).empty;
    defer url_buf.deinit(allocator);
    try url_buf.appendSlice(allocator, cfg.core_base_url);
    try url_buf.appendSlice(allocator, "/cp/api/v1.1/feeds/gamecardfeed?gamedate=");
    try url_buf.appendSlice(allocator, converted);
    try url_buf.appendSlice(allocator, "&platform=web");

    var headers = std.ArrayList(config_mod.Header).empty;
    defer headers.deinit(allocator);
    try headers.append(allocator, .{ .name = "Origin", .value = "https://www.nba.com" });
    try headers.append(allocator, .{ .name = "Ocp-Apim-Subscription-Key", .value = scoreboard_key });
    for (cfg.headers) |h| try headers.append(allocator, h);

    const body = try http.get(allocator, url_buf.items, headers.items);
    return try scoreboard.parse(allocator, body, date);
}

pub fn fetchBoxScore(allocator: std.mem.Allocator, cfg: config_mod.Config, game_id: []const u8) !boxscore.BoxScore {
    var url_buf = std.ArrayList(u8).empty;
    defer url_buf.deinit(allocator);
    try url_buf.appendSlice(allocator, cfg.base_url);
    try url_buf.appendSlice(allocator, "/boxscore/boxscore_");
    try url_buf.appendSlice(allocator, game_id);
    try url_buf.appendSlice(allocator, ".json");

    const body = try http.get(allocator, url_buf.items, cfg.headers);
    return try boxscore.parse(allocator, body);
}

pub fn fetchPlayByPlay(allocator: std.mem.Allocator, cfg: config_mod.Config, game_id: []const u8) !playbyplay.PlayByPlay {
    var url_buf = std.ArrayList(u8).empty;
    defer url_buf.deinit(allocator);
    try url_buf.appendSlice(allocator, cfg.base_url);
    try url_buf.appendSlice(allocator, "/playbyplay/playbyplay_");
    try url_buf.appendSlice(allocator, game_id);
    try url_buf.appendSlice(allocator, ".json");

    const body = try http.get(allocator, url_buf.items, cfg.headers);
    return try playbyplay.parse(allocator, body);
}
