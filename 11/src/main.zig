const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

const Operation = enum {
    mult,
    add,
};

const OpTag = enum {
    number,
    old,
};

const OpUnion = union(OpTag) {
    number: u64,
    old: void,

    fn getValue(self: OpUnion, old: u64) u64 {
        switch (self) {
            .number => |value| return value,
            .old => |_| return old,
        }
    }
};

const Monkey = struct {
    starting_items: std.ArrayList(u64),
    op: Operation,
    first_op: OpUnion,
    second_op: OpUnion,
    division: u64,
    success: usize,
    failure: usize,
    touched: u64,
};

fn parseType(name: []const u8) !OpUnion {
    if (std.mem.eql(u8, name, "old")) {
        return OpUnion{ .old = {} };
    } else {
        var num = try std.fmt.parseInt(u64, name, 10);
        return OpUnion{ .number = num };
    }
}
fn lcd(a: u64, b: u64) u64 {
    var i: u64 = 2;
    while (i < a * b) : (i += 1) {
        if ((a % i == 0) and (b % i == 0))
            return i;
    }
    return a * b;
}

pub fn main() !void {
    var arg_iterator = switch (builtin.os.tag) {
        .windows => try std.process.ArgIterator.initWithAllocator(allocator),
        else => std.process.args(),
    };

    _ = arg_iterator.next();

    var first_part = true;
    while (arg_iterator.next()) |path| {
        if (std.mem.eql(u8, path, "-2")) {
            first_part = false;
            continue;
        }

        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [2048]u8 = undefined;
        var c_monkey: Monkey = undefined;
        c_monkey.starting_items = std.ArrayList(u64).init(allocator);
        c_monkey.touched = 0;

        var c_num: usize = 0;
        var past_first = false;

        var monkeys: [10]Monkey = undefined;

        var highest: usize = 0;

        var all_lcd: u64 = 1;

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |uline| {
            var line = std.mem.trim(u8, uline, " \t");
            if (std.mem.startsWith(u8, line, "Monkey")) {
                var split = std.mem.tokenize(u8, line, " ");
                _ = split.next();
                var num = split.next().?;
                num = num[0 .. num.len - 1];
                if (past_first) {
                    if (c_num > highest) highest = c_num;
                    monkeys[c_num] = c_monkey;
                    c_monkey.starting_items = std.ArrayList(u64).init(allocator);
                    c_monkey.touched = 0;
                } else past_first = true;
                c_num = try std.fmt.parseInt(usize, num, 10);
            } else if (std.mem.startsWith(u8, line, "Starting items")) {
                var column_split = std.mem.split(u8, line, ": ");
                _ = column_split.next();
                var items = std.mem.split(u8, column_split.next().?, ", ");
                while (items.next()) |item| {
                    try c_monkey.starting_items.append(try std.fmt.parseInt(u64, item, 10));
                }
            } else if (std.mem.startsWith(u8, line, "Operation")) {
                var split = std.mem.split(u8, line, "=");
                _ = split.next();
                var expression = split.next().?;
                expression = std.mem.trim(u8, expression, " ");

                var op = "+";
                c_monkey.op = Operation.add;
                if (std.mem.indexOfPos(u8, expression, 0, "*")) |_| {
                    op = "*";
                    c_monkey.op = Operation.mult;
                }
                var exp_split = std.mem.split(u8, expression, op);
                c_monkey.first_op = try parseType(std.mem.trim(u8, exp_split.next().?, " "));
                c_monkey.second_op = try parseType(std.mem.trim(u8, exp_split.next().?, " "));
            } else if (std.mem.startsWith(u8, line, "If true")) {
                var split = std.mem.split(u8, line, "monkey ");
                _ = split.next();
                c_monkey.success = try std.fmt.parseInt(usize, split.next().?, 10);
            } else if (std.mem.startsWith(u8, line, "If false")) {
                var split = std.mem.split(u8, line, "monkey ");
                _ = split.next();
                c_monkey.failure = try std.fmt.parseInt(usize, split.next().?, 10);
            } else if (std.mem.startsWith(u8, line, "Test")) {
                var split = std.mem.split(u8, line, "by ");
                _ = split.next();
                c_monkey.division = try std.fmt.parseInt(u64, split.next().?, 10);
                all_lcd = lcd(c_monkey.division, all_lcd);
            }
        }

        if (c_num > highest) highest = c_num;
        monkeys[c_num] = c_monkey;

        var round: usize = 0;
        const rounds: usize = if (first_part) 20 else 10000;
        while (round < rounds) : (round += 1) {
            for (monkeys[0 .. highest + 1]) |*monkey| {
                for (monkey.starting_items.items) |item| {
                    var first = monkey.first_op.getValue(item);
                    var second = monkey.second_op.getValue(item);
                    var worry_level: u64 = 0;
                    if (monkey.op == Operation.mult) {
                        worry_level = first * second;
                    } else {
                        worry_level = first + second;
                    }
                    if (first_part)
                        worry_level = @divFloor(worry_level, 3);
                    worry_level = @mod(worry_level, all_lcd);

                    if (worry_level % monkey.division == 0) {
                        try monkeys[monkey.success].starting_items.append(worry_level);
                    } else {
                        try monkeys[monkey.failure].starting_items.append(worry_level);
                    }
                    monkey.touched += 1;
                }
                monkey.starting_items.clearAndFree();
            }
        }
        var values = std.ArrayList(u64).init(allocator);
        for (monkeys[0 .. highest + 1]) |check_monkey, i| {
            std.log.info("Monkey {}: {}", .{ i, check_monkey.touched });
            try values.append(check_monkey.touched);
        }
        std.sort.sort(u64, values.items, {}, std.sort.desc(u64));
        std.log.info("Monkey biz: {any}", .{values.items[0] * values.items[1]});

        first_part = true;
    }
}
