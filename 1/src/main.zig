const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

const Queue = std.TailQueue(u32);
var sorted_elfs = Queue{};

pub fn main() anyerror!void {
    var arg_iterator = switch (builtin.os.tag) {
        .windows => try std.process.ArgIterator.initWithAllocator(allocator),
        else => std.process.args(),
    };

    var biggest = Queue.Node{ .data = 0 };
    sorted_elfs.append(&biggest);

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
        var total: u32 = 0;
        while (try in_stream.readUntilDelimiterOrEofAlloc(allocator, '\n', 32768)) |number_string| {
            if (number_string.len == 0) {
                var node_or = sorted_elfs.first;
                while (node_or) |node| {
                    if (total > node.data) {
                        var new_node = try allocator.create(Queue.Node);
                        new_node.* = Queue.Node{ .data = total };
                        sorted_elfs.insertBefore(node, new_node);
                        break;
                    }
                    node_or = node.next;
                }
                total = 0;
                continue;
            }
            const val = try std.fmt.parseInt(u32, number_string, 10);
            total += val;
        }

        var i: u32 = 0;
        var node_or = sorted_elfs.first;
        var series_total: u32 = 0;
        while (i < 3) : (i += 1) {
            if (node_or) |node| {
                std.log.info("{}", .{node.data});
                series_total += node.data;
                node_or = node.next;
            }
        }
        std.log.info("{}", .{series_total});
    }
}
