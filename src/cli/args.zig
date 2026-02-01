const std = @import("std");

pub const ArgsError = error{MissingValue, UnknownOption};

pub fn requireOption(args: []const []const u8, name: []const u8) ArgsError![]const u8 {
    if (findOption(args, name)) |val| return val;
    return error.MissingValue;
}

pub fn findOption(args: []const []const u8, name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], name)) {
            if (i + 1 >= args.len) return null;
            return args[i + 1];
        }
    }
    return null;
}
