const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("bilibili_uwp_mp4_decode", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    const cflags = [_][]const u8{"-Wall"};
    exe.addIncludePath(concatAbsolPath("/nativefiledialog/src/include"));
    exe.addCSourceFile(concatAbsolPath("/nativefiledialog/src/nfd_common.c"), &cflags);
    exe.addCSourceFile(concatAbsolPath("/nativefiledialog/src/nfd_win.cpp"), &cflags);

    exe.linkLibC();
    exe.linkSystemLibrary("shell32");
    exe.linkSystemLibrary("ole32");
    exe.linkSystemLibrary("uuid");

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

fn concatAbsolPath(comptime suffix: []const u8) []const u8 {
    return comptime blk: {
        const current_dir = std.fs.path.dirname(@src().file).?;
        break :blk current_dir ++ suffix;
    };
}
