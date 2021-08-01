const std = @import("std");

fn useSdl(step: *std.build.LibExeObjStep) void {
    step.addPackagePath("sdl2", "../sdl2/src/main.zig");
    step.addIncludeDir("../sdl2/SDL/include");
    step.addLibPath("../sdl2/SDL/lib/x64");
    step.linkSystemLibrary("SDL2");
    step.linkSystemLibrary("c");
}

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("dominion", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    useSdl(exe);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);




    const main_tests = b.addTest("src/main.zig");
    useSdl(main_tests);
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&main_tests.step);
}
