const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

inline fn getPriority(char: u8) u8 {
    return if (char < 91) return char - 38 else return char - 96;
}

pub fn main() anyerror!void {
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

        var total: u32 = 0;
        var next_total: u32 = 0;

        var index: u32 = 0;

        var count_map = std.AutoHashMap(u8, u32).init(allocator);
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var existence_map = std.AutoHashMap(u8, void).init(allocator);
            defer existence_map.deinit();

            var first_half = line[0 .. line.len / 2];
            var second_half = line[line.len / 2 ..];

            for (first_half) |c| {
                try existence_map.put(c, {});
            }

            for (second_half) |c| {
                if (existence_map.getEntry(c)) |_| {
                    total += getPriority(c);
                    break;
                }
            }

            // part 2
            if (index != 2) {
                for (line) |c| {
                    var entry = try count_map.getOrPutValue(c, 0);
                    if (entry.value_ptr.* == index) entry.value_ptr.* += 1;
                }
            } else {
                for (line) |c| {
                    var entry = try count_map.getOrPutValue(c, 0);
                    if (entry.value_ptr.* == 2) {
                        next_total += getPriority(c);

                        count_map.deinit();
                        count_map = std.AutoHashMap(u8, u32).init(allocator);
                        break;
                    }
                }
            }

            index = (index + 1) % 3;
        }

        std.log.info("{} {}", .{ total, next_total });
    }
}
