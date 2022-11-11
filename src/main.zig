const std = @import("std");
const os = std.os;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const stdc = std.c;

var gpa = heap.GeneralPurposeAllocator(.{}){};
var global_allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    const open_path = try openFileDialog("mp4", null);
    if (open_path) |path| {
        defer stdc.free(@intToPtr(*anyopaque, @ptrToInt(path.ptr)));
        if (doRewrite(path)) {
            // TODO: ok msg
        } else |err| switch (err) {
            error.FileNotFound => {},
            error.BadPathName => {},
            error.AccessDenied => {},
            error.NoMatching => {
              debug.print("TODO: msg", .{});
            },
            else => debug.print("{}", .{err}),
        }
    }
}

fn doRewrite(path: []const u8) !void {
    const in_file = try fs.cwd().openFile(path, .{ .mode = .read_only });
    defer in_file.close();

    const in_file_size = try in_file.getEndPos();
    if (in_file_size < 3) return error.NoMatching;

    const in_file_buf = try in_file.reader().readAllAlloc(global_allocator, in_file_size);
    defer global_allocator.free(in_file_buf);

    const slice = in_file_buf[0..3];
    for (slice) |byte| if (byte != 0xff) return error.NoMatching;

    try fs.cwd().writeFile(path, in_file_buf[3..]);
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
        debug.print("{s}\n", .{mem.span(ptr)});
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
