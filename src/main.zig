const std = @import("std");
const os = std.os;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const heap = std.heap;
const math = std.math;
const stdc = std.c;

pub const log_level: std.log.Level = .info;
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    const prefix = "\n[" ++ comptime level.asText() ++ "] ";
    const stderr = io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}
const info = std.log.info;
const warn = std.log.warn;

pub fn main() !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    info("{s}", .{"Please select a file"});
    const open_path = try openFileDialog("mp4", null);
    if (open_path) |path| {
        defer stdc.free(@intToPtr(*anyopaque, @ptrToInt(path.ptr)));
        if (doRewrite(allocator, path)) {
            info("{s}", .{"Success"});
        } else |err| switch (err) {
            error.FileNotFound => warn("{s}", .{"File Not Found"}),
            error.BadPathName => warn("{s}", .{"Bad Path Name"}),
            error.AccessDenied => warn("{s}", .{"Access Denied"}),
            error.NotMatching => warn("{s}", .{"Not required decode. Nothing was done."}),
            else => warn("{!}", .{err}),
        }
    } else {
        warn("{s}", .{"No file selected"});
    }

    info("{s}", .{
        \\Thanks for using this tool.
        \\Press Enter to exit.
    });

    const stdin = io.getStdIn();
    var line_buf: [20]u8 = undefined;
    const amt = try stdin.read(&line_buf);
    _ = amt;
}

fn doRewrite(allocator: mem.Allocator, path: []const u8) !void {
    const file = fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| {
        warn("Unable to open file: {s}\n", .{@errorName(err)});
        return err;
    };
    defer file.close();

    var buf3: [3]u8 = undefined;
    _ = try file.read(&buf3);
    for (buf3) |byte| if (byte != 0xff) return error.NotMatching;
    info("Please wait ...", .{});

    var file_buf = std.ArrayList(u8).init(allocator);
    defer file_buf.deinit();

    const max_size = 4096 * 100;
    const file_size = try file.getEndPos();

    var written: usize = 0;
    try file.seekTo(0);
    while (written < file_size - 3) {
        try file_buf.ensureTotalCapacity(@min(max_size, file_size - written - 3));
        file_buf.expandToCapacity();

        try file.seekTo(written + 3);
        _ = try file.read(file_buf.items[0..]);

        try file.seekTo(written);
        written += try file.write(file_buf.items);
        if (written % 0x2710 == 0) {
            info("Progress: {d} / {d}", .{ written, file_size });
        }
    }
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
        info("{s}", .{mem.span(ptr)});
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
