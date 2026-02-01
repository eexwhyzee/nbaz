const std = @import("std");
const json = @import("../util/json.zig");
const pbp_mod = @import("playbyplay.zig");

pub const Meta = struct {
    version: i64,
    code: i64,
    request: []const u8,
    time: []const u8,
};

pub const BoxScore = struct {
    meta: Meta,
    game: Game,
};

pub const Game = struct {
    gameId: []const u8,
    gameStatusText: []const u8,
    gameStatus: i64,
    period: i64,
    homeTeam: Team,
    awayTeam: Team,
    officials: []Official,
};

pub const Official = struct {
    personId: i64,
    name: []const u8,
};

pub const Team = struct {
    teamId: i64,
    teamName: []const u8,
    teamCity: []const u8,
    teamTricode: []const u8,
    score: i64,
    inBonus: []const u8,
    timeoutsRemaining: i64,
    periods: []PeriodScore,
    players: []Player,
    statistics: TeamStats,
};

pub const PeriodScore = struct {
    period: i64,
    periodType: []const u8,
    score: i64,
};

pub const Player = struct {
    status: []const u8,
    order: i64,
    personId: i64,
    jerseyNum: []const u8,
    position: []const u8,
    starter: []const u8,
    oncourt: []const u8,
    played: []const u8,
    statistics: PlayerStats,
    name: []const u8,
    firstName: []const u8,
    familyName: []const u8,
    notPlayingReason: []const u8,
    notPlayingDescription: []const u8,
};

pub const PlayerStats = struct {
    name: []const u8,
    assists: i64,
    blocks: i64,
    blocksReceived: i64,
    fieldGoalsAttempted: i64,
    fieldGoalsMade: i64,
    fieldGoalsPercentage: f64,
    foulsOffensive: i64,
    foulsDrawn: i64,
    foulsPersonal: i64,
    foulsTechnical: i64,
    freeThrowsAttempted: i64,
    freeThrowsMade: i64,
    freeThrowsPercentage: f64,
    minus: f64,
    minutes: []const u8,
    minutesCalculated: []const u8,
    plus: f64,
    plusMinusPoints: f64,
    points: i64,
    pointsFastBreak: i64,
    pointsInThePaint: i64,
    pointsSecondChance: i64,
    reboundsDefensive: i64,
    reboundsOffensive: i64,
    reboundsTotal: i64,
    steals: i64,
    threePointersAttempted: i64,
    threePointersMade: i64,
    threePointersPercentage: f64,
    turnovers: i64,
    twoPointersAttempted: i64,
    twoPointersMade: i64,
    twoPointersPercentage: f64,
};

pub const TeamStats = struct {
    assists: i64,
    assistsTurnoverRatio: f64,
    benchPoints: i64,
    biggestLead: i64,
    biggestLeadScore: []const u8,
    biggestScoringRun: i64,
    biggestScoringRunScore: []const u8,
    blocks: i64,
    blocksReceived: i64,
    fastBreakPointsAttempted: i64,
    fastBreakPointsMade: i64,
    fastBreakPointsPercentage: f64,
    fieldGoalsAttempted: i64,
    fieldGoalsEffectiveAdjusted: f64,
    fieldGoalsMade: i64,
    fieldGoalsPercentage: f64,
    foulsOffensive: i64,
    foulsDrawn: i64,
    foulsPersonal: i64,
    foulsTeam: i64,
    foulsTechnical: i64,
    foulsTeamTechnical: i64,
    freeThrowsAttempted: i64,
    freeThrowsMade: i64,
    freeThrowsPercentage: f64,
    leadChanges: i64,
    minutes: []const u8,
    minutesCalculated: []const u8,
    points: i64,
    pointsAgainst: i64,
    pointsFastBreak: i64,
    pointsFromTurnovers: i64,
    pointsInThePaint: i64,
    pointsInThePaintAttempted: i64,
    pointsInThePaintMade: i64,
    pointsInThePaintPercentage: f64,
    pointsSecondChance: i64,
    reboundsDefensive: i64,
    reboundsOffensive: i64,
    reboundsPersonal: i64,
    reboundsTeam: i64,
    reboundsTeamDefensive: i64,
    reboundsTeamOffensive: i64,
    reboundsTotal: i64,
    secondChancePointsAttempted: i64,
    secondChancePointsMade: i64,
    secondChancePointsPercentage: f64,
    steals: i64,
    threePointersAttempted: i64,
    threePointersMade: i64,
    threePointersPercentage: f64,
    timeLeading: []const u8,
    timesTied: i64,
    trueShootingAttempts: f64,
    trueShootingPercentage: f64,
    turnovers: i64,
    turnoversTeam: i64,
    turnoversTotal: i64,
    twoPointersAttempted: i64,
    twoPointersMade: i64,
    twoPointersPercentage: f64,
};

pub const TeamStatsPair = struct {
    home: TeamStats,
    away: TeamStats,
};

pub const TeamCount = struct {
    teamTricode: []const u8,
    count: i64,
};

pub const RefStats = struct {
    officialId: i64,
    name: []const u8,
    calls: []pbp_mod.Action,
    foulCount: []TeamCount,
    freeThrowCount: []TeamCount,
};

pub const Side = enum { home, away };

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !BoxScore {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidBoxScore;
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

    var game: Game = .{
        .gameId = "",
        .gameStatusText = "",
        .gameStatus = 0,
        .period = 0,
        .homeTeam = emptyTeam(),
        .awayTeam = emptyTeam(),
        .officials = &.{},
    };

    if (root.get("game")) |game_val| {
        if (game_val == .object) {
            game = try parseGame(allocator, game_val.object);
        }
    }

    return .{ .meta = meta, .game = game };
}

fn parseGame(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !Game {
    var officials = std.ArrayList(Official).empty;
    defer officials.deinit(allocator);

    if (obj.get("officials")) |offs_val| {
        if (offs_val == .array) {
            for (offs_val.array.items) |oval| {
                if (oval != .object) continue;
                const oobj = oval.object;
                try officials.append(allocator, .{
                    .personId = json.getInt(oobj, "personId", 0),
                    .name = json.getString(oobj, "name", ""),
                });
            }
        }
    }

    var home_team = emptyTeam();
    if (obj.get("homeTeam")) |home_val| {
        if (home_val == .object) home_team = parseTeam(allocator, home_val.object);
    }

    var away_team = emptyTeam();
    if (obj.get("awayTeam")) |away_val| {
        if (away_val == .object) away_team = parseTeam(allocator, away_val.object);
    }

    return .{
        .gameId = json.getString(obj, "gameId", ""),
        .gameStatusText = json.getString(obj, "gameStatusText", ""),
        .gameStatus = json.getInt(obj, "gameStatus", 0),
        .period = json.getInt(obj, "period", 0),
        .homeTeam = home_team,
        .awayTeam = away_team,
        .officials = try officials.toOwnedSlice(allocator),
    };
}

fn parseTeam(allocator: std.mem.Allocator, obj: std.json.ObjectMap) Team {
    var periods = std.ArrayList(PeriodScore).empty;
    defer periods.deinit(allocator);

    if (obj.get("periods")) |periods_val| {
        if (periods_val == .array) {
            for (periods_val.array.items) |pval| {
                if (pval != .object) continue;
                const pobj = pval.object;
                _ = periods.append(allocator, .{
                    .period = json.getInt(pobj, "period", 0),
                    .periodType = json.getString(pobj, "periodType", ""),
                    .score = json.getInt(pobj, "score", 0),
                }) catch {};
            }
        }
    }

    var players = std.ArrayList(Player).empty;
    defer players.deinit(allocator);

    if (obj.get("players")) |players_val| {
        if (players_val == .array) {
            for (players_val.array.items) |pval| {
                if (pval != .object) continue;
                _ = players.append(allocator, parsePlayer(pval.object)) catch {};
            }
        }
    }

    var stats: TeamStats = emptyTeamStats();
    if (obj.get("statistics")) |stats_val| {
        if (stats_val == .object) stats = parseTeamStats(stats_val.object);
    }

    return .{
        .teamId = json.getInt(obj, "teamId", 0),
        .teamName = json.getString(obj, "teamName", ""),
        .teamCity = json.getString(obj, "teamCity", ""),
        .teamTricode = json.getString(obj, "teamTricode", ""),
        .score = json.getInt(obj, "score", 0),
        .inBonus = json.getString(obj, "inBonus", ""),
        .timeoutsRemaining = json.getInt(obj, "timeoutsRemaining", 0),
        .periods = periods.toOwnedSlice(allocator) catch &.{},
        .players = players.toOwnedSlice(allocator) catch &.{},
        .statistics = stats,
    };
}

fn parsePlayer(obj: std.json.ObjectMap) Player {
    var stats: PlayerStats = emptyPlayerStats();
    if (obj.get("statistics")) |stats_val| {
        if (stats_val == .object) stats = parsePlayerStats(stats_val.object);
    }

    return .{
        .status = json.getString(obj, "status", ""),
        .order = json.getInt(obj, "order", 0),
        .personId = json.getInt(obj, "personId", 0),
        .jerseyNum = json.getString(obj, "jerseyNum", ""),
        .position = json.getString(obj, "position", ""),
        .starter = json.getString(obj, "starter", ""),
        .oncourt = json.getString(obj, "oncourt", ""),
        .played = json.getString(obj, "played", ""),
        .statistics = stats,
        .name = json.getString(obj, "name", ""),
        .firstName = json.getString(obj, "firstName", ""),
        .familyName = json.getString(obj, "familyName", ""),
        .notPlayingReason = json.getString(obj, "notPlayingReason", ""),
        .notPlayingDescription = json.getString(obj, "notPlayingDescription", ""),
    };
}

fn parsePlayerStats(obj: std.json.ObjectMap) PlayerStats {
    return .{
        .name = "",
        .assists = json.getInt(obj, "assists", 0),
        .blocks = json.getInt(obj, "blocks", 0),
        .blocksReceived = json.getInt(obj, "blocksReceived", 0),
        .fieldGoalsAttempted = json.getInt(obj, "fieldGoalsAttempted", 0),
        .fieldGoalsMade = json.getInt(obj, "fieldGoalsMade", 0),
        .fieldGoalsPercentage = json.getFloat(obj, "fieldGoalsPercentage", 0.0),
        .foulsOffensive = json.getInt(obj, "foulsOffensive", 0),
        .foulsDrawn = json.getInt(obj, "foulsDrawn", 0),
        .foulsPersonal = json.getInt(obj, "foulsPersonal", 0),
        .foulsTechnical = json.getInt(obj, "foulsTechnical", 0),
        .freeThrowsAttempted = json.getInt(obj, "freeThrowsAttempted", 0),
        .freeThrowsMade = json.getInt(obj, "freeThrowsMade", 0),
        .freeThrowsPercentage = json.getFloat(obj, "freeThrowsPercentage", 0.0),
        .minus = json.getFloat(obj, "minus", 0.0),
        .minutes = json.getString(obj, "minutes", ""),
        .minutesCalculated = json.getString(obj, "minutesCalculated", ""),
        .plus = json.getFloat(obj, "plus", 0.0),
        .plusMinusPoints = json.getFloat(obj, "plusMinusPoints", 0.0),
        .points = json.getInt(obj, "points", 0),
        .pointsFastBreak = json.getInt(obj, "pointsFastBreak", 0),
        .pointsInThePaint = json.getInt(obj, "pointsInThePaint", 0),
        .pointsSecondChance = json.getInt(obj, "pointsSecondChance", 0),
        .reboundsDefensive = json.getInt(obj, "reboundsDefensive", 0),
        .reboundsOffensive = json.getInt(obj, "reboundsOffensive", 0),
        .reboundsTotal = json.getInt(obj, "reboundsTotal", 0),
        .steals = json.getInt(obj, "steals", 0),
        .threePointersAttempted = json.getInt(obj, "threePointersAttempted", 0),
        .threePointersMade = json.getInt(obj, "threePointersMade", 0),
        .threePointersPercentage = json.getFloat(obj, "threePointersPercentage", 0.0),
        .turnovers = json.getInt(obj, "turnovers", 0),
        .twoPointersAttempted = json.getInt(obj, "twoPointersAttempted", 0),
        .twoPointersMade = json.getInt(obj, "twoPointersMade", 0),
        .twoPointersPercentage = json.getFloat(obj, "twoPointersPercentage", 0.0),
    };
}

fn parseTeamStats(obj: std.json.ObjectMap) TeamStats {
    return .{
        .assists = json.getInt(obj, "assists", 0),
        .assistsTurnoverRatio = json.getFloat(obj, "assistsTurnoverRatio", 0.0),
        .benchPoints = json.getInt(obj, "benchPoints", 0),
        .biggestLead = json.getInt(obj, "biggestLead", 0),
        .biggestLeadScore = json.getString(obj, "biggestLeadScore", ""),
        .biggestScoringRun = json.getInt(obj, "biggestScoringRun", 0),
        .biggestScoringRunScore = json.getString(obj, "biggestScoringRunScore", ""),
        .blocks = json.getInt(obj, "blocks", 0),
        .blocksReceived = json.getInt(obj, "blocksReceived", 0),
        .fastBreakPointsAttempted = json.getInt(obj, "fastBreakPointsAttempted", 0),
        .fastBreakPointsMade = json.getInt(obj, "fastBreakPointsMade", 0),
        .fastBreakPointsPercentage = json.getFloat(obj, "fastBreakPointsPercentage", 0.0),
        .fieldGoalsAttempted = json.getInt(obj, "fieldGoalsAttempted", 0),
        .fieldGoalsEffectiveAdjusted = json.getFloat(obj, "fieldGoalsEffectiveAdjusted", 0.0),
        .fieldGoalsMade = json.getInt(obj, "fieldGoalsMade", 0),
        .fieldGoalsPercentage = json.getFloat(obj, "fieldGoalsPercentage", 0.0),
        .foulsOffensive = json.getInt(obj, "foulsOffensive", 0),
        .foulsDrawn = json.getInt(obj, "foulsDrawn", 0),
        .foulsPersonal = json.getInt(obj, "foulsPersonal", 0),
        .foulsTeam = json.getInt(obj, "foulsTeam", 0),
        .foulsTechnical = json.getInt(obj, "foulsTechnical", 0),
        .foulsTeamTechnical = json.getInt(obj, "foulsTeamTechnical", 0),
        .freeThrowsAttempted = json.getInt(obj, "freeThrowsAttempted", 0),
        .freeThrowsMade = json.getInt(obj, "freeThrowsMade", 0),
        .freeThrowsPercentage = json.getFloat(obj, "freeThrowsPercentage", 0.0),
        .leadChanges = json.getInt(obj, "leadChanges", 0),
        .minutes = json.getString(obj, "minutes", ""),
        .minutesCalculated = json.getString(obj, "minutesCalculated", ""),
        .points = json.getInt(obj, "points", 0),
        .pointsAgainst = json.getInt(obj, "pointsAgainst", 0),
        .pointsFastBreak = json.getInt(obj, "pointsFastBreak", 0),
        .pointsFromTurnovers = json.getInt(obj, "pointsFromTurnovers", 0),
        .pointsInThePaint = json.getInt(obj, "pointsInThePaint", 0),
        .pointsInThePaintAttempted = json.getInt(obj, "pointsInThePaintAttempted", 0),
        .pointsInThePaintMade = json.getInt(obj, "pointsInThePaintMade", 0),
        .pointsInThePaintPercentage = json.getFloat(obj, "pointsInThePaintPercentage", 0.0),
        .pointsSecondChance = json.getInt(obj, "pointsSecondChance", 0),
        .reboundsDefensive = json.getInt(obj, "reboundsDefensive", 0),
        .reboundsOffensive = json.getInt(obj, "reboundsOffensive", 0),
        .reboundsPersonal = json.getInt(obj, "reboundsPersonal", 0),
        .reboundsTeam = json.getInt(obj, "reboundsTeam", 0),
        .reboundsTeamDefensive = json.getInt(obj, "reboundsTeamDefensive", 0),
        .reboundsTeamOffensive = json.getInt(obj, "reboundsTeamOffensive", 0),
        .reboundsTotal = json.getInt(obj, "reboundsTotal", 0),
        .secondChancePointsAttempted = json.getInt(obj, "secondChancePointsAttempted", 0),
        .secondChancePointsMade = json.getInt(obj, "secondChancePointsMade", 0),
        .secondChancePointsPercentage = json.getFloat(obj, "secondChancePointsPercentage", 0.0),
        .steals = json.getInt(obj, "steals", 0),
        .threePointersAttempted = json.getInt(obj, "threePointersAttempted", 0),
        .threePointersMade = json.getInt(obj, "threePointersMade", 0),
        .threePointersPercentage = json.getFloat(obj, "threePointersPercentage", 0.0),
        .timeLeading = json.getString(obj, "timeLeading", ""),
        .timesTied = json.getInt(obj, "timesTied", 0),
        .trueShootingAttempts = json.getFloat(obj, "trueShootingAttempts", 0.0),
        .trueShootingPercentage = json.getFloat(obj, "trueShootingPercentage", 0.0),
        .turnovers = json.getInt(obj, "turnovers", 0),
        .turnoversTeam = json.getInt(obj, "turnoversTeam", 0),
        .turnoversTotal = json.getInt(obj, "turnoversTotal", 0),
        .twoPointersAttempted = json.getInt(obj, "twoPointersAttempted", 0),
        .twoPointersMade = json.getInt(obj, "twoPointersMade", 0),
        .twoPointersPercentage = json.getFloat(obj, "twoPointersPercentage", 0.0),
    };
}

fn emptyTeam() Team {
    return .{
        .teamId = 0,
        .teamName = "",
        .teamCity = "",
        .teamTricode = "",
        .score = 0,
        .inBonus = "",
        .timeoutsRemaining = 0,
        .periods = &.{},
        .players = &.{},
        .statistics = emptyTeamStats(),
    };
}

fn emptyPlayerStats() PlayerStats {
    return .{
        .name = "",
        .assists = 0,
        .blocks = 0,
        .blocksReceived = 0,
        .fieldGoalsAttempted = 0,
        .fieldGoalsMade = 0,
        .fieldGoalsPercentage = 0.0,
        .foulsOffensive = 0,
        .foulsDrawn = 0,
        .foulsPersonal = 0,
        .foulsTechnical = 0,
        .freeThrowsAttempted = 0,
        .freeThrowsMade = 0,
        .freeThrowsPercentage = 0.0,
        .minus = 0.0,
        .minutes = "",
        .minutesCalculated = "",
        .plus = 0.0,
        .plusMinusPoints = 0.0,
        .points = 0,
        .pointsFastBreak = 0,
        .pointsInThePaint = 0,
        .pointsSecondChance = 0,
        .reboundsDefensive = 0,
        .reboundsOffensive = 0,
        .reboundsTotal = 0,
        .steals = 0,
        .threePointersAttempted = 0,
        .threePointersMade = 0,
        .threePointersPercentage = 0.0,
        .turnovers = 0,
        .twoPointersAttempted = 0,
        .twoPointersMade = 0,
        .twoPointersPercentage = 0.0,
    };
}

fn emptyTeamStats() TeamStats {
    return .{
        .assists = 0,
        .assistsTurnoverRatio = 0.0,
        .benchPoints = 0,
        .biggestLead = 0,
        .biggestLeadScore = "",
        .biggestScoringRun = 0,
        .biggestScoringRunScore = "",
        .blocks = 0,
        .blocksReceived = 0,
        .fastBreakPointsAttempted = 0,
        .fastBreakPointsMade = 0,
        .fastBreakPointsPercentage = 0.0,
        .fieldGoalsAttempted = 0,
        .fieldGoalsEffectiveAdjusted = 0.0,
        .fieldGoalsMade = 0,
        .fieldGoalsPercentage = 0.0,
        .foulsOffensive = 0,
        .foulsDrawn = 0,
        .foulsPersonal = 0,
        .foulsTeam = 0,
        .foulsTechnical = 0,
        .foulsTeamTechnical = 0,
        .freeThrowsAttempted = 0,
        .freeThrowsMade = 0,
        .freeThrowsPercentage = 0.0,
        .leadChanges = 0,
        .minutes = "",
        .minutesCalculated = "",
        .points = 0,
        .pointsAgainst = 0,
        .pointsFastBreak = 0,
        .pointsFromTurnovers = 0,
        .pointsInThePaint = 0,
        .pointsInThePaintAttempted = 0,
        .pointsInThePaintMade = 0,
        .pointsInThePaintPercentage = 0.0,
        .pointsSecondChance = 0,
        .reboundsDefensive = 0,
        .reboundsOffensive = 0,
        .reboundsPersonal = 0,
        .reboundsTeam = 0,
        .reboundsTeamDefensive = 0,
        .reboundsTeamOffensive = 0,
        .reboundsTotal = 0,
        .secondChancePointsAttempted = 0,
        .secondChancePointsMade = 0,
        .secondChancePointsPercentage = 0.0,
        .steals = 0,
        .threePointersAttempted = 0,
        .threePointersMade = 0,
        .threePointersPercentage = 0.0,
        .timeLeading = "",
        .timesTied = 0,
        .trueShootingAttempts = 0.0,
        .trueShootingPercentage = 0.0,
        .turnovers = 0,
        .turnoversTeam = 0,
        .turnoversTotal = 0,
        .twoPointersAttempted = 0,
        .twoPointersMade = 0,
        .twoPointersPercentage = 0.0,
    };
}

pub fn getTeamStats(bs: BoxScore) TeamStatsPair {
    return .{
        .home = bs.game.homeTeam.statistics,
        .away = bs.game.awayTeam.statistics,
    };
}

pub fn getPlayerStats(allocator: std.mem.Allocator, bs: BoxScore, side: Side) ![]PlayerStats {
    const players = switch (side) {
        .home => bs.game.homeTeam.players,
        .away => bs.game.awayTeam.players,
    };

    var result = std.ArrayList(PlayerStats).empty;
    defer result.deinit(allocator);

    for (players) |p| {
        var ps = p.statistics;
        ps.name = p.name;
        const mins = convertMinutes(ps.minutes);
        const rounded = std.math.ceil(mins);
        var buf: [32]u8 = undefined;
        const str = std.fmt.bufPrint(&buf, "{d}", .{@as(i64, @intFromFloat(rounded))}) catch "0";
        ps.minutes = str;
        try result.append(allocator, ps);
    }

    return try result.toOwnedSlice(allocator);
}

pub fn getRefStats(allocator: std.mem.Allocator, bs: BoxScore, pbp: pbp_mod.PlayByPlay) ![]RefStats {
    var refs = std.AutoHashMap(i64, RefStatsBuilder).init(allocator);
    defer refs.deinit();

    for (bs.game.officials) |o| {
        try refs.put(o.personId, .{ .officialId = o.personId, .name = o.name, .calls = std.ArrayList(pbp_mod.Action).empty, .foulCount = std.StringHashMap(i64).init(allocator), .freeThrowCount = std.StringHashMap(i64).init(allocator) });
    }

    var action_index: usize = 0;
    while (action_index < pbp.game.actions.len) : (action_index += 1) {
        const action = pbp.game.actions[action_index];
        if (action.officialId == 0) continue;

        if (std.mem.eql(u8, action.actionType, "turnover") and std.mem.eql(u8, action.subType, "offensive foul")) {
            continue;
        }
        if (std.mem.eql(u8, action.actionType, "turnover") and std.mem.eql(u8, action.subType, "out-of-bounds")) {
            continue;
        }

        if (refs.getPtr(action.officialId)) |ref| {
            try ref.calls.append(allocator, action);
        }
    }

    var it = refs.iterator();
    while (it.next()) |entry| {
        const ref = entry.value_ptr;
        for (ref.calls.items) |c| {
            if (std.mem.eql(u8, c.actionType, "foul")) {
                const key = c.teamTricode;
                const prev = ref.foulCount.get(key) orelse 0;
                try ref.foulCount.put(key, prev + 1);

                const ft_count = parseFreeThrowCount(c.description);
                if (ft_count > 0) {
                    const prev_ft = ref.freeThrowCount.get(key) orelse 0;
                    try ref.freeThrowCount.put(key, prev_ft + ft_count);
                }
            }
        }
    }

    var results = std.ArrayList(RefStats).empty;
    defer results.deinit(allocator);

    var it2 = refs.iterator();
    while (it2.next()) |entry| {
        const ref = entry.value_ptr;
        try results.append(allocator, ref.finalize(allocator));
    }

    return try results.toOwnedSlice(allocator);
}

const RefStatsBuilder = struct {
    officialId: i64,
    name: []const u8,
    calls: std.ArrayList(pbp_mod.Action),
    foulCount: std.StringHashMap(i64),
    freeThrowCount: std.StringHashMap(i64),

    fn finalize(self: *RefStatsBuilder, allocator: std.mem.Allocator) RefStats {
        var foul_counts = std.ArrayList(TeamCount).empty;
        var free_throw_counts = std.ArrayList(TeamCount).empty;
        var it = self.foulCount.iterator();
        while (it.next()) |entry| {
            _ = foul_counts.append(allocator, .{ .teamTricode = entry.key_ptr.*, .count = entry.value_ptr.* }) catch {};
        }
        var it2 = self.freeThrowCount.iterator();
        while (it2.next()) |entry| {
            _ = free_throw_counts.append(allocator, .{ .teamTricode = entry.key_ptr.*, .count = entry.value_ptr.* }) catch {};
        }
        return .{
            .officialId = self.officialId,
            .name = self.name,
            .calls = self.calls.toOwnedSlice(allocator) catch &.{},
            .foulCount = foul_counts.toOwnedSlice(allocator) catch &.{},
            .freeThrowCount = free_throw_counts.toOwnedSlice(allocator) catch &.{},
        };
    }
};

fn parseFreeThrowCount(desc: []const u8) i64 {
    const marker = " FT";
    const idx = std.mem.indexOf(u8, desc, marker) orelse return 0;
    if (idx == 0) return 0;
    var start = idx;
    while (start > 0 and std.ascii.isDigit(desc[start - 1])) : (start -= 1) {}
    if (start == idx) return 0;
    return std.fmt.parseInt(i64, desc[start..idx], 10) catch 0;
}

// Helper util functions
fn convertMinutes(minutes: []const u8) f64 {
    if (minutes.len < 3) return 0.0;
    if (!std.mem.startsWith(u8, minutes, "PT")) return 0.0;
    const m_idx = std.mem.indexOfScalar(u8, minutes, 'M') orelse return 0.0;
    const mins_str = minutes[2..m_idx];
    const mins = std.fmt.parseFloat(f64, mins_str) catch 0.0;
    const s_idx = std.mem.indexOfScalar(u8, minutes, 'S');
    if (s_idx) |idx| {
        const secs_str = minutes[m_idx + 1 .. idx];
        if (secs_str.len == 0) return mins;
        const secs = std.fmt.parseFloat(f64, secs_str) catch 0.0;
        return mins + secs / 60.0;
    }
    return mins;
}

// Tests

test "parse boxscore fixture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const data = @embedFile("../testdata/boxscore.json");
    const bs = try parse(allocator, data);
    try std.testing.expectEqualStrings("001", bs.game.gameId);
    try std.testing.expectEqual(@as(usize, 2), bs.game.homeTeam.players.len);
}

test "convertMinutes formats" {
    try std.testing.expectEqual(@as(f64, 41.0), convertMinutes("PT41M"));
    try std.testing.expectEqual(@as(f64, 35.5), convertMinutes("PT35M30.00S"));
}

test "getRefStats counts fouls and free throws" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bs_data = @embedFile("../testdata/boxscore.json");
    const pbp_data = @embedFile("../testdata/playbyplay.json");
    const bs = try parse(allocator, bs_data);
    const pbp = try pbp_mod.parse(allocator, pbp_data);
    const refs = try getRefStats(allocator, bs, pbp);
    try std.testing.expect(refs.len >= 1);
    const ref = refs[0];
    const foul = findTeamCount(ref.foulCount, "HOM");
    const ft = findTeamCount(ref.freeThrowCount, "HOM");
    try std.testing.expectEqual(@as(i64, 1), foul);
    try std.testing.expectEqual(@as(i64, 2), ft);
}

fn findTeamCount(counts: []TeamCount, tricode: []const u8) i64 {
    for (counts) |c| {
        if (std.mem.eql(u8, c.teamTricode, tricode)) return c.count;
    }
    return 0;
}
