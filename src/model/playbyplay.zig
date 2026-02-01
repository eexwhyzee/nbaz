const std = @import("std");
const json = @import("../util/json.zig");

pub const Meta = struct {
    version: i64,
    code: i64,
    request: []const u8,
    time: []const u8,
};

pub const PlayByPlay = struct {
    meta: Meta,
    game: Game,
};

pub const Game = struct {
    gameId: []const u8,
    actions: []Action,
};

pub const Action = struct {
    actionNumber: i64,
    clock: []const u8,
    period: i64,
    actionType: []const u8,
    subType: []const u8,
    qualifiers: []const []const u8,
    personId: i64,
    teamId: i64,
    teamTricode: []const u8,
    description: []const u8,
    officialId: i64,
    isFieldGoal: i64,
    x: f64,
    y: f64,
    shotDistance: f64,
    shotResult: []const u8,
    playerName: []const u8,
    descriptor: []const u8,
};

// Shot represents a single shot attempt with location and result
pub const Shot = struct {
    player_id: i64,
    player_name: []const u8,
    period: i64,
    clock: []const u8,
    x: f64,
    y: f64,
    zone: []const u8,
    distance: f64,
    shot_type: []const u8,
    result: []const u8,
    description: []const u8,
};

// PlayerShotChart aggregates shots for a single player
pub const PlayerShotChart = struct {
    player_id: i64,
    player_name: []const u8,
    shots: []Shot,
    total_shots: i64,
    made_shots: i64,
    paint_fga: i64,
    paint_fgm: i64,
    mid_range_fga: i64,
    mid_range_fgm: i64,
    corner_3_fga: i64,
    corner_3_fgm: i64,
    above_break_3_fga: i64,
    above_break_3_fgm: i64,
};

// TeamShotChart aggregates shots for a team with player breakdowns
pub const TeamShotChart = struct {
    team_id: i64,
    team_tricode: []const u8,
    all_shots: []Shot,
    by_player: []PlayerShotChart,
    total_shots: i64,
    made_shots: i64,
    paint_fga: i64,
    paint_fgm: i64,
    mid_range_fga: i64,
    mid_range_fgm: i64,
    corner_3_fga: i64,
    corner_3_fgm: i64,
    above_break_3_fga: i64,
    above_break_3_fgm: i64,
};

pub const ShotChart = struct {
    home: ?TeamShotChart,
    away: ?TeamShotChart,
};

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !PlayByPlay {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidPlayByPlay;
    const root = parsed.value.object;

    var meta: Meta = .{ .version = 0, .code = 0, .request = "", .time = "" };
    if (root.get("meta")) |meta_val| {
        if (meta_val == .object) {
            const mobj = meta_val.object;
            meta = .{
                .version = json.getInt(mobj, "version", 0),
                .code = json.getInt(mobj, "code", 0),
                .request = json.getString(mobj, "request", ""),
                .time = json.getString(mobj, "time", ""),
            };
        }
    }

    var game: Game = .{ .gameId = "", .actions = &.{} };
    if (root.get("game")) |game_val| {
        if (game_val == .object) {
            game = try parseGame(allocator, game_val.object);
        }
    }

    return .{ .meta = meta, .game = game };
}

fn parseGame(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !Game {
    const game_id = json.getString(obj, "gameId", "");

    var actions_list = std.ArrayList(Action).empty;
    defer actions_list.deinit(allocator);

    if (obj.get("actions")) |actions_val| {
        if (actions_val == .array) {
            for (actions_val.array.items) |action_val| {
                if (action_val != .object) continue;
                const action = parseAction(allocator, action_val.object);
                try actions_list.append(allocator, action);
            }
        }
    }

    return .{ .gameId = game_id, .actions = try actions_list.toOwnedSlice(allocator) };
}

fn parseAction(allocator: std.mem.Allocator, obj: std.json.ObjectMap) Action {
    var qualifiers_list = std.ArrayList([]const u8).empty;
    defer qualifiers_list.deinit(allocator);

    if (obj.get("qualifiers")) |qval| {
        if (qval == .array) {
            for (qval.array.items) |item| {
                if (item == .string) {
                    _ = qualifiers_list.append(allocator, item.string) catch {};
                }
            }
        }
    }

    return .{
        .actionNumber = json.getInt(obj, "actionNumber", 0),
        .clock = json.getString(obj, "clock", ""),
        .period = json.getInt(obj, "period", 0),
        .actionType = json.getString(obj, "actionType", ""),
        .subType = json.getString(obj, "subType", ""),
        .qualifiers = qualifiers_list.toOwnedSlice(allocator) catch &.{},
        .personId = json.getInt(obj, "personId", 0),
        .teamId = json.getInt(obj, "teamId", 0),
        .teamTricode = json.getString(obj, "teamTricode", ""),
        .description = json.getString(obj, "description", ""),
        .officialId = json.getInt(obj, "officialId", 0),
        .isFieldGoal = json.getInt(obj, "isFieldGoal", 0),
        .x = parseCoordinate(obj.get("x")),
        .y = parseCoordinate(obj.get("y")),
        .shotDistance = json.getFloat(obj, "shotDistance", 0.0),
        .shotResult = json.getString(obj, "shotResult", ""),
        .playerName = json.getString(obj, "playerName", ""),
        .descriptor = json.getString(obj, "descriptor", ""),
    };
}

// classifyZone determines the court zone based on shot location and distance
pub fn classifyZone(y: f64, distance: f64) []const u8 {
    if (distance < 8) return "paint";
    if (distance >= 22) {
        if (y < 14 or y > 86) return "corner_3";
        return "above_break_3";
    }
    return "mid_range";
}

pub fn parseCoordinate(maybe_value: ?std.json.Value) f64 {
    if (maybe_value == null) return 0.0;
    const value = maybe_value.?;
    return json.valueToFloat(value);
}

pub fn getShotChart(allocator: std.mem.Allocator, pbp: PlayByPlay, home_team_id: i64, away_team_id: i64) !ShotChart {
    var teams = std.ArrayList(TeamShotChartBuilder).empty;
    defer teams.deinit(allocator);

    for (pbp.game.actions) |action| {
        if (action.isFieldGoal != 1) continue;

        const zone = classifyZone(action.y, action.shotDistance);
        const is_made = std.mem.eql(u8, action.shotResult, "Made");

        const shot: Shot = .{
            .player_id = action.personId,
            .player_name = action.playerName,
            .period = action.period,
            .clock = action.clock,
            .x = action.x,
            .y = action.y,
            .zone = zone,
            .distance = action.shotDistance,
            .shot_type = action.subType,
            .result = action.shotResult,
            .description = action.description,
        };

        var team_builder = try findOrCreateTeam(allocator, &teams, action.teamId, action.teamTricode);
        try team_builder.all_shots.append(allocator, shot);
        team_builder.total_shots += 1;
        if (is_made) team_builder.made_shots += 1;
        updateZoneCounts(team_builder, zone, is_made);

        var player_builder = try findOrCreatePlayer(allocator, team_builder, action.personId, action.playerName);
        try player_builder.shots.append(allocator, shot);
        player_builder.total_shots += 1;
        if (is_made) player_builder.made_shots += 1;
        updatePlayerZoneCounts(player_builder, zone, is_made);
    }

    var home_chart: ?TeamShotChart = null;
    var away_chart: ?TeamShotChart = null;

    for (teams.items) |*builder| {
        const chart = try builder.finalize();
        if (builder.team_id == home_team_id) {
            home_chart = chart;
        } else if (builder.team_id == away_team_id) {
            away_chart = chart;
        }
    }

    return .{ .home = home_chart, .away = away_chart };
}

const TeamShotChartBuilder = struct {
    allocator: std.mem.Allocator,
    team_id: i64,
    team_tricode: []const u8,
    all_shots: std.ArrayList(Shot),
    by_player: std.ArrayList(PlayerShotChartBuilder),
    total_shots: i64,
    made_shots: i64,
    paint_fga: i64,
    paint_fgm: i64,
    mid_range_fga: i64,
    mid_range_fgm: i64,
    corner_3_fga: i64,
    corner_3_fgm: i64,
    above_break_3_fga: i64,
    above_break_3_fgm: i64,

    fn finalize(self: *TeamShotChartBuilder) !TeamShotChart {
        var players = std.ArrayList(PlayerShotChart).empty;
        defer players.deinit(self.allocator);
        for (self.by_player.items) |*pb| {
            try players.append(self.allocator, pb.finalize(self.allocator));
        }

        return .{
            .team_id = self.team_id,
            .team_tricode = self.team_tricode,
            .all_shots = try self.all_shots.toOwnedSlice(self.allocator),
            .by_player = try players.toOwnedSlice(self.allocator),
            .total_shots = self.total_shots,
            .made_shots = self.made_shots,
            .paint_fga = self.paint_fga,
            .paint_fgm = self.paint_fgm,
            .mid_range_fga = self.mid_range_fga,
            .mid_range_fgm = self.mid_range_fgm,
            .corner_3_fga = self.corner_3_fga,
            .corner_3_fgm = self.corner_3_fgm,
            .above_break_3_fga = self.above_break_3_fga,
            .above_break_3_fgm = self.above_break_3_fgm,
        };
    }
};

const PlayerShotChartBuilder = struct {
    allocator: std.mem.Allocator,
    player_id: i64,
    player_name: []const u8,
    shots: std.ArrayList(Shot),
    total_shots: i64,
    made_shots: i64,
    paint_fga: i64,
    paint_fgm: i64,
    mid_range_fga: i64,
    mid_range_fgm: i64,
    corner_3_fga: i64,
    corner_3_fgm: i64,
    above_break_3_fga: i64,
    above_break_3_fgm: i64,

    fn finalize(self: *PlayerShotChartBuilder, allocator: std.mem.Allocator) PlayerShotChart {
        return .{
            .player_id = self.player_id,
            .player_name = self.player_name,
            .shots = self.shots.toOwnedSlice(allocator) catch &.{},
            .total_shots = self.total_shots,
            .made_shots = self.made_shots,
            .paint_fga = self.paint_fga,
            .paint_fgm = self.paint_fgm,
            .mid_range_fga = self.mid_range_fga,
            .mid_range_fgm = self.mid_range_fgm,
            .corner_3_fga = self.corner_3_fga,
            .corner_3_fgm = self.corner_3_fgm,
            .above_break_3_fga = self.above_break_3_fga,
            .above_break_3_fgm = self.above_break_3_fgm,
        };
    }
};

fn findOrCreateTeam(allocator: std.mem.Allocator, list: *std.ArrayList(TeamShotChartBuilder), team_id: i64, tricode: []const u8) !*TeamShotChartBuilder {
    for (list.items) |*item| {
        if (item.team_id == team_id) return item;
    }
    try list.append(allocator, .{
        .allocator = allocator,
        .team_id = team_id,
        .team_tricode = tricode,
        .all_shots = std.ArrayList(Shot).empty,
        .by_player = std.ArrayList(PlayerShotChartBuilder).empty,
        .total_shots = 0,
        .made_shots = 0,
        .paint_fga = 0,
        .paint_fgm = 0,
        .mid_range_fga = 0,
        .mid_range_fgm = 0,
        .corner_3_fga = 0,
        .corner_3_fgm = 0,
        .above_break_3_fga = 0,
        .above_break_3_fgm = 0,
    });
    return &list.items[list.items.len - 1];
}

fn findOrCreatePlayer(allocator: std.mem.Allocator, team: *TeamShotChartBuilder, player_id: i64, player_name: []const u8) !*PlayerShotChartBuilder {
    for (team.by_player.items) |*item| {
        if (item.player_id == player_id) return item;
    }
    try team.by_player.append(allocator, .{
        .allocator = allocator,
        .player_id = player_id,
        .player_name = player_name,
        .shots = std.ArrayList(Shot).empty,
        .total_shots = 0,
        .made_shots = 0,
        .paint_fga = 0,
        .paint_fgm = 0,
        .mid_range_fga = 0,
        .mid_range_fgm = 0,
        .corner_3_fga = 0,
        .corner_3_fgm = 0,
        .above_break_3_fga = 0,
        .above_break_3_fgm = 0,
    });
    return &team.by_player.items[team.by_player.items.len - 1];
}

fn updateZoneCounts(team: *TeamShotChartBuilder, zone: []const u8, made: bool) void {
    if (std.mem.eql(u8, zone, "paint")) {
        team.paint_fga += 1;
        if (made) team.paint_fgm += 1;
    } else if (std.mem.eql(u8, zone, "mid_range")) {
        team.mid_range_fga += 1;
        if (made) team.mid_range_fgm += 1;
    } else if (std.mem.eql(u8, zone, "corner_3")) {
        team.corner_3_fga += 1;
        if (made) team.corner_3_fgm += 1;
    } else if (std.mem.eql(u8, zone, "above_break_3")) {
        team.above_break_3_fga += 1;
        if (made) team.above_break_3_fgm += 1;
    }
}

fn updatePlayerZoneCounts(player: *PlayerShotChartBuilder, zone: []const u8, made: bool) void {
    if (std.mem.eql(u8, zone, "paint")) {
        player.paint_fga += 1;
        if (made) player.paint_fgm += 1;
    } else if (std.mem.eql(u8, zone, "mid_range")) {
        player.mid_range_fga += 1;
        if (made) player.mid_range_fgm += 1;
    } else if (std.mem.eql(u8, zone, "corner_3")) {
        player.corner_3_fga += 1;
        if (made) player.corner_3_fgm += 1;
    } else if (std.mem.eql(u8, zone, "above_break_3")) {
        player.above_break_3_fga += 1;
        if (made) player.above_break_3_fgm += 1;
    }
}

test "classifyZone" {
    try std.testing.expectEqualStrings("paint", classifyZone(50, 3));
    try std.testing.expectEqualStrings("mid_range", classifyZone(50, 15));
    try std.testing.expectEqualStrings("corner_3", classifyZone(5, 22));
    try std.testing.expectEqualStrings("above_break_3", classifyZone(50, 24));
}

test "parseCoordinate" {
    const v1 = std.json.Value{ .float = 25.5 };
    const v2 = std.json.Value{ .integer = 50 };
    const v3 = std.json.Value{ .null = {} };
    try std.testing.expectEqual(@as(f64, 25.5), parseCoordinate(v1));
    try std.testing.expectEqual(@as(f64, 50.0), parseCoordinate(v2));
    try std.testing.expectEqual(@as(f64, 0.0), parseCoordinate(v3));
}

test "shot chart fixture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const data = @embedFile("../testdata/playbyplay.json");
    const pbp = try parse(allocator, data);
    const chart = try getShotChart(allocator, pbp, 100, 200);
    try std.testing.expect(chart.home != null);
    try std.testing.expect(chart.away != null);
}
