const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

const Range = struct {
    from: u32,
    to: u32,

    fn contains(self: *Range, sub_range: Range) bool {
        return self.from <= sub_range.from and self.to >= sub_range.to;
    }

    fn overlap(self: *Range, sub_range: Range) bool {
        return self.from <= sub_range.to and self.to >= sub_range.from;
    }
};

fn parseRange(range: []const u8) !Range {
    var split = std.mem.split(u8, range, "-");
    var first_field = split.next().?;
    var second_field = split.next().?;

    return Range{ .from = try std.fmt.parseInt(u32, first_field, 10), .to = try std.fmt.parseInt(u32, second_field, 10) };
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

        var count: u32 = 0;
        var overlap_count: u32 = 0;

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var split = std.mem.split(u8, line, ",");
            var first_range = try parseRange(split.next().?);
            var second_range = try parseRange(split.next().?);
            if (first_range.contains(second_range) or second_range.contains(first_range))
                count += 1;
            if (first_range.overlap(second_range))
                overlap_count += 1;
        }

        std.log.info("{} {}", .{ count, overlap_count });
    }
}
