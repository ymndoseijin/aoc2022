const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

inline fn reverse(array: anytype) void {
    for (array.items[0 .. array.items.len / 2]) |t, i| {
        array.items[i] = array.items[array.items.len - i - 1];
        array.items[array.items.len - i - 1] = t;
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

        var stacks: [9]std.ArrayList(u8) = undefined;
        var exciting_stacks: [9]std.ArrayList(u8) = undefined;

        for (stacks) |*stack| {
            stack.* = std.ArrayList(u8).init(allocator);
        }

        var in_stacks = true;

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 0)
                continue;

            var tokens = std.mem.tokenize(u8, line, " ");

            if (in_stacks) {
                while (tokens.next()) |token| {
                    if (token[0] != '[') {
                        in_stacks = false;
                        for (stacks) |*stack, j| {
                            reverse(stack);

                            exciting_stacks[j] = try stack.clone();
                        }
                        break;
                    }
                    var index = tokens.index / 4;
                    try stacks[index].append(token[1]);
                }
            } else {
                _ = tokens.next();
                var times = try std.fmt.parseInt(u32, tokens.next().?, 10);
                _ = tokens.next();
                var from = try std.fmt.parseInt(u32, tokens.next().?, 10) - 1;
                _ = tokens.next();
                var to = try std.fmt.parseInt(u32, tokens.next().?, 10) - 1;

                var i: u32 = 0;
                var crates = std.ArrayList(u8).init(allocator);
                defer crates.deinit();

                while (i < times) : (i += 1) {
                    try crates.append(exciting_stacks[from].pop());
                    try stacks[to].append(stacks[from].pop());
                }

                reverse(crates);

                for (crates.items) |crate| {
                    try exciting_stacks[to].append(crate);
                }
            }
        }

        var part1: [9]u8 = undefined;
        var part2: [9]u8 = undefined;
        for (stacks) |stack, i| {
            part1[i] = stack.items[stack.items.len - 1];
        }
        for (exciting_stacks) |stack, i| {
            part2[i] = stack.items[stack.items.len - 1];
        }

        std.log.info("{s} {s}", .{ part1, part2 });
    }
}
