const Logging = @This();
const std = @import("std");
const allocPrintZ = std.fmt.allocPrintZ;
const bufferedWriter = std.io.bufferedWriter;
const Allocator = std.mem.Allocator;
const ArgSetType = u32;
const max_format_args = @typeInfo(ArgSetType).Int.bits;
const max_stack_buffer_size: usize = 512;

allocator: Allocator = undefined,
tag: []const u8 = undefined,

pub fn init(allocator: Allocator, tag: []const u8) Logging {
    const self = Logging{
        .allocator = allocator,
        .tag = tag,
    };
    errdefer self.deinit();
    return self;
}

pub fn deinit(self: *Logging) void {
    self.* = undefined;
}

pub fn log(self: *Logging, comptime fmt: [:0]const u8, args: anytype) void {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);
    if (args_type_info != .Struct) {
        @compileError("Expected tuple or struct argument, found " ++ @typeName(ArgsType));
    }
    const fields_info = args_type_info.Struct.fields;
    if (fields_info.len > max_format_args) {
        @compileError("32 arguments max are supported per format call");
    }

    const args_text: [:0]const u8 = std.fmt.allocPrintZ(self.allocator, fmt, args) catch {
        std.io.getStdOut().writer().print("error occurred during log formatting!\n", .{}) catch unreachable;
        return;
    };
    defer self.allocator.free(args_text);

    const writer = std.io.getStdOut().writer();
    var buffered_writer = bufferedWriter(writer);
    var stdout_writer = buffered_writer.writer();

    stdout_writer.print("{s}", .{self.tag}) catch unreachable;

    if (args_text.len > max_stack_buffer_size) {
        stdout_writer.writeAll(args_text[0..max_stack_buffer_size]) catch unreachable;
    } else {
        stdout_writer.writeAll(args_text) catch unreachable;
    }

    stdout_writer.print("\n", .{}) catch unreachable;

    buffered_writer.flush() catch {
        std.io.getStdErr().writer().print("ERROR: could not write buffered log data to stdout\n", .{}) catch unreachable;
    };
}
