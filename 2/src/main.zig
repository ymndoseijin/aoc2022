const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

inline fn checkValue(player: u8) u32 {
    switch (player) {
        'X' => return 1,
        'Y' => return 2,
        'Z' => return 3,
        else => {
            std.log.info("{c}", .{player});
            @panic("OOO WEEE OOO WEE");
        },
    }
}

inline fn checkWin(enemy: u8, player: u8) u32 {
    switch (player) {
        'X' => {
            if (enemy == 'B') {
                return 0;
            } else if (enemy == 'C') {
                return 6;
            } else {
                return 3;
            }
        },
        'Y' => {
            if (enemy == 'C') {
                return 0;
            } else if (enemy == 'A') {
                return 6;
            } else {
                return 3;
            }
        },
        'Z' => {
            if (enemy == 'A') {
                return 0;
            } else if (enemy == 'B') {
                return 6;
            } else {
                return 3;
            }
        },
        else => {
            std.log.info("{c}", .{player});
            @panic("OOO WEEE OOO WEE");
        },
    }
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
        var ultra_total: u32 = 0;

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var enemy: u8 = line[0];
            var player: u8 = line[2];

            var result = checkWin(enemy, player) + checkValue(player);
            total += result;

            switch (player) {
                'X' => {
                    if (enemy == 'A') {
                        player = 'Z';
                    } else if (enemy == 'B') {
                        player = 'X';
                    } else {
                        player = 'Y';
                    }
                },
                'Y' => {
                    if (enemy == 'A') {
                        player = 'X';
                    } else if (enemy == 'B') {
                        player = 'Y';
                    } else {
                        player = 'Z';
                    }
                },
                'Z' => {
                    if (enemy == 'A') {
                        player = 'Y';
                    } else if (enemy == 'B') {
                        player = 'Z';
                    } else {
                        player = 'X';
                    }
                },
                else => {
                    std.log.info("{c}", .{player});
                    @panic("OOO WEEE OOO WEE");
                },
            }

            ultra_total += checkWin(enemy, player) + checkValue(player);
        }

        std.log.info("{}", .{total});
        std.log.info("{}", .{ultra_total});
    }
}
