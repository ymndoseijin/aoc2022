const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

fn hasRepeat(comptime T: type, slice: []T) bool {
    for (slice) |c, j| for (slice) |d, k| if (j != k and c == d) return true;
    return false;
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

        var marker: [4]u8 = undefined;
        var no_marker = true;

        var buffer = try in_stream.readAllAlloc(allocator, 1048576);
        defer allocator.free(buffer);

        for (buffer) |byte, index| {
            var message: [14]u8 = undefined;

            marker[index % 4] = byte;
            if (index % 4 == 3 and no_marker) {
                const result = hasRepeat(u8, &marker);
                if (!result) {
                    std.log.info("part one at {} for {s}", .{ index + 1, marker });
                    no_marker = false;
                }
            }

            var i: usize = 0;
            while (i < 14 and i + index < buffer.len) : (i += 1) {
                message[i] = buffer[i + index];
                if (i == 13) {
                    const result = hasRepeat(u8, &message);
                    if (!result) {
                        std.log.info("part two at {} for {s}", .{ index + 14, message });
                        break;
                    }
                }
            }
        }
    }
}
