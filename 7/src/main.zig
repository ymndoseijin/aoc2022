const std = @import("std");
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

const Dir = struct {
    name: []const u8,
    did_ls: bool,
    parent: *Dir,
    files: std.StringArrayHashMap(File),
};

var root: *Dir = undefined;
var current_dir: *Dir = undefined;

var current_path: std.ArrayList([]const u8) = undefined;

const FileContent = struct {
    name: []const u8,
    size: u64,
};

const FileTag = enum {
    file,
    dir,
};

const File = union(FileTag) {
    file: FileContent,
    dir: *Dir,
};

var weird_total: u64 = 0;
var true_total: u64 = 0;

var candidates = std.ArrayList(u64).init(allocator);

fn find(dir: *Dir, level: u64) !u64 {
    //std.log.info("{}: at {s}", .{ level, dir.name });
    var iter = dir.files.iterator();
    var total: u64 = 0;
    while (iter.next()) |entry| {
        switch (entry.value_ptr.*) {
            FileTag.file => |value| {
                //std.log.info("{s}: {}", .{ value.name, value.size });
                total += value.size;
            },
            FileTag.dir => |value| {
                total += try find(value, level + 1);
            },
        }
    }

    if (total <= 100000)
        weird_total += total;
    return total;
}

fn free(dir: *Dir, level: u64) !u64 {
    var iter = dir.files.iterator();
    var total: u64 = 0;
    while (iter.next()) |entry| {
        switch (entry.value_ptr.*) {
            FileTag.file => |value| {
                //std.log.info("{s}: {}", .{ value.name, value.size });
                total += value.size;
                allocator.free(value.name);
            },
            FileTag.dir => |value| {
                total += try free(value, level + 1);
            },
        }
    }

    try if (total >= (30000000 - (70000000 - true_total)))
        candidates.append(total);

    allocator.free(dir.name);
    dir.files.deinit();
    allocator.free(@ptrCast(*[1]Dir, dir));

    return total;
}

fn touchSize(path: []const u8, size: u64) !void {
    try current_dir.files.put(path, File{ .file = FileContent{ .name = path, .size = size } });
}

fn mkDir(path: []const u8) !*Dir {
    var result = current_dir.files.get(path);
    if (result) |actual| {
        allocator.free(path);
        return actual.dir;
    } else {
        var new_dir = try allocator.create(Dir);
        new_dir.did_ls = false;
        new_dir.name = path;
        new_dir.parent = current_dir;
        new_dir.files = std.StringArrayHashMap(File).init(allocator);

        try current_dir.files.put(path, File{ .dir = new_dir });

        return new_dir;
    }
}

pub fn main() !void {
    defer _ = gpa.deinit();
    defer candidates.deinit();
    defer current_path.deinit();
    defer for (current_path.items) |ptr| allocator.free(ptr);

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

        var in_ls = false;

        current_path = std.ArrayList([]const u8).init(allocator);
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line[0] == '$') {
                if (in_ls) {
                    current_dir.did_ls = true;
                }

                in_ls = false;
                var args = std.mem.tokenize(u8, line[2..], " ");
                var arg0 = args.next().?;
                if (std.mem.eql(u8, arg0, "cd")) {
                    var arg1 = args.next().?;
                    if (std.mem.eql(u8, arg1, "/")) {
                        root = try allocator.create(Dir);
                        root.did_ls = false;
                        root.name = "";
                        root.files = std.StringArrayHashMap(File).init(allocator);
                        current_dir = root;
                        continue;
                    }

                    if (std.mem.eql(u8, arg1, "..")) {
                        allocator.free(current_path.pop());
                        current_dir = current_dir.parent;
                    } else {
                        current_dir = try mkDir(try allocator.dupe(u8, arg1));
                        try current_path.append(try allocator.dupe(u8, arg1));
                    }
                } else if (std.mem.eql(u8, arg0, "ls")) {
                    in_ls = true;
                }
            } else {
                if (in_ls and !current_dir.did_ls) {
                    var args = std.mem.tokenize(u8, line, " ");
                    var arg0 = args.next().?;

                    if (std.mem.eql(u8, arg0, "dir")) {
                        var new_dir_name = args.next().?;

                        _ = try mkDir(try allocator.dupe(u8, new_dir_name));
                    } else {
                        var size = try std.fmt.parseInt(u64, arg0, 10);
                        try touchSize(try allocator.dupe(u8, args.next().?), size);
                    }
                }
            }
        }

        true_total = try find(root, 0);
        _ = try free(root, 0);
        std.log.info("part 1: {}", .{weird_total});
        std.sort.sort(u64, candidates.items, {}, std.sort.asc(u64));
        std.log.info("part 2: {}", .{candidates.items[0]});
    }
}
