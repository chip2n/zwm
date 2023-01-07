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

    const exe = b.addExecutable("zwm", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.linkSystemLibrary("X11");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //Xephyr -br -ac -noreset -screen 800x600 :1
    // const run2_cmd = b.addSystemCommand(&[_][]const u8{
    //     "Xephyr",
    //     "-br",
    //     "-ac",
    //     "-noreset",
    //     "-screen",
    //     "800x600",
    //     ":1",
    // });
    const run2_cmd = b.addSystemCommand(&[_][]const u8{
        "/home/chip/dev/zwm/run-xephyr.sh",
    });
    run2_cmd.step.dependOn(b.getInstallStep());
    const run2_step = b.step("run-xephyr", "Run the WM in Xephyr");
    run2_step.dependOn(&run2_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    exe_tests.linkLibC();
    exe_tests.linkSystemLibrary("X11");

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
