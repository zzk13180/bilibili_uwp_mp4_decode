const std = @import("std");
const Logging = @import("Logging.zig");
const os = std.os;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const heap = std.heap;
const time = std.time;
const math = std.math;
const stdc = std.c;

const ArrayList = std.ArrayList;

var gpa = heap.GeneralPurposeAllocator(.{}){};
var global_allocator = gpa.allocator();

const LOG_TAG: [:0]const u8 = "";
var logging: Logging = undefined;

pub fn main() !void {
    defer _ = gpa.deinit();
    defer _ = logging.deinit();

    logging = Logging.init(global_allocator, LOG_TAG);
    logging.log("{s}", .{"Please select a file to decode"});

    const open_path = try openFileDialog("mp4", null);
    if (open_path) |path| {
        defer stdc.free(@intToPtr(*anyopaque, @ptrToInt(path.ptr)));
        if (doRewrite(path)) {
            logging.log("\n{s}\n", .{"Success"});
        } else |err| switch (err) {
            error.FileNotFound => logging.log("\n{s}\n", .{"File Not Found"}),
            error.BadPathName => logging.log("\n{s}\n", .{"Bad Path Name"}),
            error.AccessDenied => logging.log("\n{s}\n", .{"Access Denied"}),
            error.NotMatching => logging.log("\n{s}\n", .{"Not required decode. Nothing was done."}),
            else => logging.log("\n{!}\n", .{err}),
        }
    } else {
        logging.log("\n{s}\n", .{"No file selected"});
    }

    logging.log("{s}", .{"End"});
    logging.log("{s}", .{"Thanks for using this tool"});
    time.sleep(1 * time.ns_per_s);
    logging.log("{s}", .{"Bye"});
    time.sleep(1 * time.ns_per_s);
}

fn doRewrite(path: []const u8) !void {
    logging.log("selected : {s}", .{path});
    const file = try fs.cwd().openFile(path, .{ .mode = .read_write });
    defer file.close();
    const file_size = try file.getEndPos();

    var buf3: [3]u8 = undefined;
    _ = try file.read(&buf3);
    for (buf3) |byte| if (byte != 0xff) return error.NotMatching;
    logging.log("Please wait ... ", .{});
    logging.log("File size : {d}", .{file_size});

    var file_buf = ArrayList(u8).init(global_allocator);
    try file_buf.ensureTotalCapacity(@min(math.maxInt(u23), file_size));
    file_buf.expandToCapacity();
    _ = try file.read(file_buf.items[0..]);

    try file.seekTo(0);
    var written = try file.write(file_buf.items);

    while (written < file_size - 3) {
        logging.log("Already written : {d}", .{written});
        try file.seekTo(written + 3);
        file_buf.deinit();
        file_buf = ArrayList(u8).init(global_allocator);
        try file_buf.ensureTotalCapacity(@min(math.maxInt(u23), file_size - written - 3));
        file_buf.expandToCapacity();
        _ = try file.read(file_buf.items[0..]);
        try file.seekTo(written);
        written += try file.write(file_buf.items);
    }

    file_buf.deinit();
    try file.setEndPos(file_size - 3);
}

// #region OpenDialog
// https://github.com/fabioarnold/nfd-zig
const char_t = u8;
const result_t = c_int;
const NFD_ERROR: c_int = 0;
const NFD_OKAY: c_int = 1;
const NFD_CANCEL: c_int = 2;
const Error = error{
    NfdError,
};
extern fn NFD_OpenDialog(filterList: [*c]const char_t, defaultPath: [*c]const char_t, outPath: [*c][*c]char_t) result_t;
extern fn NFD_GetError() [*c]const u8;
fn openFileError() Error {
    if (NFD_GetError()) |ptr| {
        logging.log("{s}\n", .{mem.span(ptr)});
    }
    return error.NfdError;
}
fn openFileDialog(filter: ?[:0]const u8, default_path: ?[:0]const u8) Error!?[:0]const u8 {
    var out_path: [*c]u8 = null;
    const result = NFD_OpenDialog(if (filter != null) filter.?.ptr else null, if (default_path != null) default_path.?.ptr else null, &out_path);
    return switch (result) {
        NFD_OKAY => if (out_path == null) null else mem.sliceTo(out_path, 0),
        NFD_ERROR => openFileError(),
        else => null,
    };
}
// #endregion OpenDialog
