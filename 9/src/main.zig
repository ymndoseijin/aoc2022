const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

fn toVec2(direction: u8) @Vector(2, i32) {
    switch (direction) {
        'U' => return .{ 0, 1 },
        'D' => return .{ 0, -1 },
        'L' => return .{ -1, 0 },
        'R' => return .{ 1, 0 },
        else => return .{ 0, 0 },
    }
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

        var tails = [1]@Vector(2, i32){@Vector(2, i32){ 0, 0 }} ** 10;

        var hash = std.AutoArrayHashMap(@Vector(2, i32), usize).init(allocator);

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var iter = std.mem.split(u8, line, " ");
            var direction = toVec2(iter.next().?[0]);
            var times = try std.fmt.parseInt(i32, iter.next().?, 10);

            var i: u32 = 0;
            while (i < times) : (i += 1) {
                tails[0] += direction;
                var previous = tails[0];

                var current_direction = direction;

                var num: usize = 0;
                for (tails[1..]) |*current| {
                    var difference = previous - current.*;
                    current_direction = difference / @Vector(2, i32){ 2, 2 };
                    var abs = difference;
                    if (difference[0] < 0) abs[0] *= -1;
                    if (difference[1] < 0) abs[1] *= -1;

                    if (abs[0] > 1 or abs[1] > 1) {
                        if (difference[0] == 0 or difference[1] == 0) {
                            current.* += current_direction;
                        } else {
                            if (abs[0] > 1) difference[0] = @divExact(difference[0], abs[0]);
                            if (abs[1] > 1) difference[1] = @divExact(difference[1], abs[1]);
                            current.* += difference;
                        }
                        if (num == 8) {
                            var return_val = try hash.getOrPut(current.*);
                            return_val.value_ptr.* += 1;
                        }
                    }

                    previous = current.*;
                    num += 1;
                }
            }
        }

        var hash_iter = hash.iterator();
        var count: usize = 1;
        while (hash_iter.next()) |_| {
            count += 1;
        }
        std.log.info("{}", .{count});
    }
}
