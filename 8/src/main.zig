const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

var rows = std.ArrayList([]const u8).init(allocator);

inline fn hloop(slice: []const u8, char: u8, blocking: *usize, orient: bool) usize {
    var loop_score: usize = 0;
    var not_blocked = true;
    for (slice) |i| {
        if (i >= char) {
            if (not_blocked) {
                blocking.* += 1;
                not_blocked = false;
            }
            if (orient) return loop_score + 1;
            loop_score = 0;
        }
        loop_score += 1;
    }
    return loop_score;
}

inline fn vloop(slice: [][]const u8, x: usize, char: u8, blocking: *usize, orient: bool) usize {
    var loop_score: usize = 0;
    var not_blocked = true;
    for (slice) |i| {
        if (i[x] >= char) {
            if (not_blocked) {
                blocking.* += 1;
                not_blocked = false;
            }
            if (orient) return loop_score + 1;
            loop_score = 0;
        }
        loop_score += 1;
    }
    return loop_score;
}

pub fn main() !void {
    var arg_iterator = switch (builtin.os.tag) {
        .windows => try std.process.ArgIterator.initWithAllocator(allocator),
        else => std.process.args(),
    };

    var first = true;

    while (arg_iterator.next()) |path| {
        if (first) {
            first = false;
            continue;
        }

        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [2048]u8 = undefined;

        var get_first = true;
        var width: usize = 0;

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (get_first) width = line.len;

            try rows.append(try allocator.dupe(u8, line));
        }

        var count: usize = 0;

        var y: usize = 0;
        var highest_score: usize = 0;
        for (rows.items) |row| {
            var x: usize = 0;
            for (row) |tree| {
                defer x += 1;

                var score: usize = 1;
                var blocking: usize = 0;

                score *= vloop(rows.items[0..y], x, tree, &blocking, false);
                score *= hloop(row[0..x], tree, &blocking, false);
                score *= vloop(rows.items[y + 1 ..], x, tree, &blocking, true);
                score *= hloop(row[x + 1 ..], tree, &blocking, true);

                if (blocking < 4) count += 1;
                if (highest_score < score) highest_score = score;
            }
            y += 1;
        }
        std.log.info("total {} {}", .{ count, highest_score });
    }
}
