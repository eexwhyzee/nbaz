const std = @import("std");
const json = @import("../util/json.zig");

pub const ScoreBoard = struct {
    scoreboard: ScoreboardData,
};

pub const ScoreboardData = struct {
    gameDate: []const u8,
    games: []Game,
};

pub const Game = struct {
    gameId: []const u8,
    gameStatus: i64,
    gameStatusText: []const u8,
    period: i64,
    gameClock: []const u8,
    gameTimeUTC: []const u8,
    gameEt: []const u8,
    homeTeam: Team,
    awayTeam: Team,
};

pub const Team = struct {
    teamId: i64,
    teamName: []const u8,
    wins: i64,
    losses: i64,
    teamSubtitle: []const u8,
    score: i64,
    timeoutsRemaining: i64,
    inBonus: bool,
    teamTricode: []const u8,
    periods: []PeriodScore,
    teamLeader: TeamLeader,
};

pub const PeriodScore = struct {
    period: i64,
    score: i64,
};

pub const TeamLeader = struct {
    personId: i64,
    name: []const u8,
    jerseyNum: []const u8,
    position: []const u8,
    teamTricode: []const u8,
    playerSlug: []const u8,
    points: []const u8,
    rebounds: []const u8,
    assists: []const u8,
    blocks: []const u8,
    steals: []const u8,
};

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8, date: []const u8) !ScoreBoard {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidScoreboard;
    const root = parsed.value.object;

    var games_list = std.ArrayList(Game).empty;
    defer games_list.deinit(allocator);

    if (root.get("modules")) |modules_val| {
        if (modules_val == .array and modules_val.array.items.len > 0) {
            const module0 = modules_val.array.items[0];
            if (module0 == .object) {
                if (module0.object.get("cards")) |cards_val| {
                    if (cards_val == .array) {
                        for (cards_val.array.items) |card_val| {
                            if (card_val != .object) continue;
                            const card_obj = card_val.object;
                            const card_data_val = card_obj.get("cardData") orelse continue;
                            if (card_data_val != .object) continue;
                            const game = parseGame(allocator, card_data_val.object);
                            try games_list.append(allocator, game);
                        }
                    }
                }
            }
        }
    }

    return .{
        .scoreboard = .{
            .gameDate = date,
            .games = try games_list.toOwnedSlice(allocator),
        },
    };
}

fn parseGame(allocator: std.mem.Allocator, obj: std.json.ObjectMap) Game {
    const game_id = json.getString(obj, "gameId", "");
    const game_status = json.getInt(obj, "gameStatus", 0);
    const game_status_text = json.getString(obj, "gameStatusText", "");
    const period = json.getInt(obj, "period", 0);
    const game_clock = json.getString(obj, "gameClock", "");
    const game_time_utc = json.getString(obj, "gameTimeUtc", "");
    const game_time_et = json.getString(obj, "gameTimeEastern", "");

    var home_team: Team = emptyTeam();
    if (obj.get("homeTeam")) |home_val| {
        if (home_val == .object) home_team = parseTeam(allocator, home_val.object);
    }

    var away_team: Team = emptyTeam();
    if (obj.get("awayTeam")) |away_val| {
        if (away_val == .object) away_team = parseTeam(allocator, away_val.object);
    }

    return .{
        .gameId = game_id,
        .gameStatus = game_status,
        .gameStatusText = game_status_text,
        .period = period,
        .gameClock = game_clock,
        .gameTimeUTC = game_time_utc,
        .gameEt = game_time_et,
        .homeTeam = home_team,
        .awayTeam = away_team,
    };
}

fn parseTeam(allocator: std.mem.Allocator, obj: std.json.ObjectMap) Team {
    var periods_list = std.ArrayList(PeriodScore).empty;
    defer periods_list.deinit(allocator);

    if (obj.get("periods")) |periods_val| {
        if (periods_val == .array) {
            for (periods_val.array.items) |pval| {
                if (pval != .object) continue;
                const pobj = pval.object;
                const period = json.getInt(pobj, "period", 0);
                const score = json.getInt(pobj, "score", 0);
                _ = periods_list.append(allocator, .{ .period = period, .score = score }) catch {};
            }
        }
    }

    var leader: TeamLeader = .{
        .personId = 0,
        .name = "",
        .jerseyNum = "",
        .position = "",
        .teamTricode = "",
        .playerSlug = "",
        .points = "",
        .rebounds = "",
        .assists = "",
        .blocks = "",
        .steals = "",
    };

    if (obj.get("teamLeader")) |leader_val| {
        if (leader_val == .object) {
            const lobj = leader_val.object;
            leader = .{
                .personId = json.getInt(lobj, "personId", 0),
                .name = json.getString(lobj, "name", ""),
                .jerseyNum = json.getString(lobj, "jerseyNum", ""),
                .position = json.getString(lobj, "position", ""),
                .teamTricode = json.getString(lobj, "teamTricode", ""),
                .playerSlug = json.getString(lobj, "playerSlug", ""),
                .points = json.getString(lobj, "points", ""),
                .rebounds = json.getString(lobj, "rebounds", ""),
                .assists = json.getString(lobj, "assists", ""),
                .blocks = json.getString(lobj, "blocks", ""),
                .steals = json.getString(lobj, "steals", ""),
            };
        }
    }

    return .{
        .teamId = json.getInt(obj, "teamId", 0),
        .teamName = json.getString(obj, "teamName", ""),
        .wins = json.getInt(obj, "wins", 0),
        .losses = json.getInt(obj, "losses", 0),
        .teamSubtitle = json.getString(obj, "teamSubtitle", ""),
        .score = json.getInt(obj, "score", 0),
        .timeoutsRemaining = json.getInt(obj, "timeoutsRemaining", 0),
        .inBonus = json.getBool(obj, "inBonus", false),
        .teamTricode = json.getString(obj, "teamTricode", ""),
        .periods = periods_list.toOwnedSlice(allocator) catch &.{},
        .teamLeader = leader,
    };
}

fn emptyTeam() Team {
    return .{
        .teamId = 0,
        .teamName = "",
        .wins = 0,
        .losses = 0,
        .teamSubtitle = "",
        .score = 0,
        .timeoutsRemaining = 0,
        .inBonus = false,
        .teamTricode = "",
        .periods = &.{},
        .teamLeader = .{
            .personId = 0,
            .name = "",
            .jerseyNum = "",
            .position = "",
            .teamTricode = "",
            .playerSlug = "",
            .points = "",
            .rebounds = "",
            .assists = "",
            .blocks = "",
            .steals = "",
        },
    };
}

test "parse scoreboard fixture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const data = @embedFile("../testdata/scoreboard.json");
    const sb = try parse(allocator, data, "20240101");
    try std.testing.expectEqual(@as(usize, 2), sb.scoreboard.games.len);
    try std.testing.expectEqualStrings("001", sb.scoreboard.games[0].gameId);
}
