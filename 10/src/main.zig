const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

const CRT = struct {
    display: [6][40]u8,

    pub fn spriteVal(self: *CRT, cycle: usize, pos: i32) void {
        var ux = (cycle - 1) % 40;
        var y = @divFloor(cycle - 1, 40);

        var x = @intCast(i32, ux);
        if (x - pos >= -1 and x - pos <= 1) self.display[y][ux] = '#' else self.display[y][ux] = '.';
    }
};

pub fn main() !void {
    var arg_iterator = switch (builtin.os.tag) {
        .windows => try std.process.ArgIterator.initWithAllocator(allocator),
        else => std.process.args(),
    };

    var first = true;

    var cycles = [_]i32{ 20, 60, 100, 140, 180, 220 };

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

        var cycle: usize = 1;
        var x_register: i32 = 1;

        var sum: i32 = 0;

        var crt = CRT{ .display = .{.{0} ** 40} ** 6 };

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var splittled = std.mem.split(u8, line, " ");
            var instruction = splittled.next().?;

            if (std.mem.eql(u8, instruction, "addx")) {
                crt.spriteVal(cycle, x_register);
                crt.spriteVal(cycle + 1, x_register);
                for (cycles) |candidate| {
                    if (candidate >= cycle and candidate <= cycle + 1) {
                        sum += x_register * candidate;
                    }
                }

                x_register += try std.fmt.parseInt(i32, splittled.next().?, 10);
                cycle += 2;
            } else {
                crt.spriteVal(cycle, x_register);
                for (cycles) |candidate| {
                    if (candidate == cycle) {
                        sum += x_register * candidate;
                    }
                }
                cycle += 1;
            }
        }
        std.log.info("sum: {}", .{sum});
        for (crt.display) |line|
            std.log.info("{s}", .{line});
    }
}
