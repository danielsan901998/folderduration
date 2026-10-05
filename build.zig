const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a minimal C stub that includes the FFmpeg header
    const c_stub = b.path("src/avformat_stub.c");

    const translate_c = b.addTranslateC(.{
        .root_source_file = c_stub,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    translate_c.linkSystemLibrary("avformat", .{});
    translate_c.linkSystemLibrary("avutil", .{});

    // Create module from translated C code
    const avformat_module = translate_c.createModule();

    const exe = b.addExecutable(.{
        .name = "folderduration",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("avformat", avformat_module);
    exe.root_module.linkSystemLibrary("avformat", .{});
    exe.root_module.linkSystemLibrary("avutil", .{});
    exe.root_module.link_libc = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    exe_unit_tests.root_module.linkSystemLibrary("avformat", .{});
    exe_unit_tests.root_module.linkSystemLibrary("avutil", .{});
    exe_unit_tests.root_module.link_libc = true;

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    run_exe_unit_tests.addPassthruArgs();

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
