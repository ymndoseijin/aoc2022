const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

const Point = struct {
    pos: @Vector(2, usize),
    cost: *std.AutoHashMap(@Vector(2, usize), u64),
};

const Problem = struct {
    height_map: [][]u8,
    queue: std.PriorityQueue(Point, void, sortScore),
    cost_map: std.AutoHashMap(@Vector(2, usize), u64),
    before_map: std.AutoHashMap(@Vector(2, usize), @Vector(2, usize)),
    start: @Vector(2, usize),
    end: @Vector(2, usize),
    part_one: bool,

    pub fn init(start: @Vector(2, usize), end: @Vector(2, usize), height_map: [][]u8, part_one: bool) !Problem {
        var queue = std.PriorityQueue(Point, void, sortScore).init(allocator, {});
        var cost_map = std.AutoHashMap(@Vector(2, usize), u64).init(allocator);
        var before_map = std.AutoHashMap(@Vector(2, usize), @Vector(2, usize)).init(allocator);
        try cost_map.put(start, 0);
        try queue.add(Point{ .pos = start, .cost = &cost_map });

        std.log.info("{} to {}", .{ start, end });

        return Problem{ .height_map = height_map, .queue = queue, .cost_map = cost_map, .before_map = before_map, .end = end, .start = start, .part_one = part_one };
    }

    fn addToQueue(self: *Problem, pos: @Vector(2, usize), preceding: @Vector(2, usize), score: u64) !void {
        try self.cost_map.put(pos, score);
        try self.before_map.put(pos, preceding);

        var neighbor_point = Point{ .pos = pos, .cost = &self.cost_map };
        var iter = self.queue.iterator();
        var none = true;

        while (iter.next()) |val| {
            if (val.pos[0] == pos[0] and val.pos[1] == pos[1]) {
                none = false;
                break;
            }
        }

        if (none) try self.queue.add(neighbor_point);
    }

    fn partOne(self: *Problem, pos: @Vector(2, usize)) bool {
        return pos[0] == self.end[0] and pos[1] == self.end[1];
    }

    fn partTwo(self: *Problem, pos: @Vector(2, usize)) bool {
        return self.height_map[pos[0]][pos[1]] == 'a';
    }

    pub fn solve(self: *Problem) !void {
        while (self.queue.len > 0) {
            var pos = self.queue.remove().pos;
            if ((self.part_one and self.partOne(pos)) or (!self.part_one and self.partTwo(pos))) {
                var count: usize = 0;
                std.log.info("found: {}", .{pos});
                var position = pos;
                while (self.before_map.get(position)) |new_pos| {
                    count += 1;
                    self.height_map[new_pos[0]][new_pos[1]] = '@';
                    position = new_pos;
                }
                std.log.info("count: {}", .{count});
                for (self.height_map) |row| {
                    for (row) |c, i| {
                        if (c != '@') row[i] = '.';
                    }
                    std.log.info("{s}", .{row});
                }
                break;
            }

            var neighbors = std.ArrayList(@Vector(2, usize)).init(allocator);
            defer neighbors.deinit();
            if (pos[0] != self.height_map.len - 1) try neighbors.append(.{ pos[0] + 1, pos[1] });
            if (pos[1] != self.height_map[0].len - 1) try neighbors.append(.{ pos[0], pos[1] + 1 });
            if (pos[0] != 0) try neighbors.append(.{ pos[0] - 1, pos[1] });
            if (pos[1] != 0) try neighbors.append(.{ pos[0], pos[1] - 1 });

            for (neighbors.items) |neighbor_pos| {
                var neighbor = self.height_map[neighbor_pos[0]][neighbor_pos[1]];
                var current_height = self.height_map[pos[0]][pos[1]];
                if ((!self.part_one and neighbor >= current_height - 1) or (self.part_one and current_height >= neighbor - 1)) {
                    var score = self.cost_map.get(pos).? + 1;
                    if (self.cost_map.get(neighbor_pos)) |old_cost| {
                        if (old_cost > score) try self.addToQueue(neighbor_pos, pos, score);
                    } else try self.addToQueue(neighbor_pos, pos, score);
                }
            }
        }
    }
};

fn sortScore(context: void, a: Point, b: Point) std.math.Order {
    _ = context;
    return std.math.order(a.cost.get(a.pos).?, b.cost.get(b.pos).?);
}

pub fn main() !void {
    var arg_iterator = switch (builtin.os.tag) {
        .windows => try std.process.ArgIterator.initWithAllocator(allocator),
        else => std.process.args(),
    };

    _ = arg_iterator.next();

    while (arg_iterator.next()) |path| {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [2048]u8 = undefined;

        var height_one = std.ArrayList([]u8).init(allocator);
        var height_two = std.ArrayList([]u8).init(allocator);

        var width: usize = 0;
        var start: @Vector(2, usize) = undefined;
        var end: @Vector(2, usize) = undefined;

        var loop_y: usize = 0;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            width = line.len;
            var row = try allocator.dupe(u8, line);
            for (line) |char, loop_x| {
                if (char == 'S') {
                    row[loop_x] = 'a';
                    start = @Vector(2, usize){ loop_y, loop_x };
                } else if (char == 'E') {
                    row[loop_x] = 'z';
                    end = @Vector(2, usize){ loop_y, loop_x };
                }
            }
            try height_one.append(row);
            try height_two.append(try allocator.dupe(u8, row));

            loop_y += 1;
        }
        var part_1 = try Problem.init(start, end, height_one.items, true);
        try part_1.solve();
        var part_2 = try Problem.init(end, undefined, height_two.items, false);
        try part_2.solve();
    }
}
