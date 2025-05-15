const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });
    const optimize = b.standardOptimizeOption(.{});

    const libpotrace = b.addStaticLibrary(.{
        .name = "potrace",
        .target = target,
        .optimize = optimize,
    });
    const libpotrace_flags = .{ "-std=gnu17", "-DHAVE_CONFIG_H" };
    libpotrace.linkLibC();
    libpotrace.addIncludePath(b.path("lib/potrace-1.16/src"));
    libpotrace.addIncludePath(b.path("lib/potrace-config"));
    libpotrace.addCSourceFile(.{ .file = b.path("lib/potrace-1.16/src/curve.c"), .flags = &libpotrace_flags });
    libpotrace.addCSourceFile(.{ .file = b.path("lib/potrace-1.16/src/trace.c"), .flags = &libpotrace_flags });
    libpotrace.addCSourceFile(.{ .file = b.path("lib/potrace-1.16/src/decompose.c"), .flags = &libpotrace_flags });
    libpotrace.addCSourceFile(.{ .file = b.path("lib/potrace-1.16/src/potracelib.c"), .flags = &libpotrace_flags });

    const libclipper2 = b.addStaticLibrary(.{
        .name = "clipper2",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const libclipper2_flags = .{ "-std=gnu++17", "-fno-exceptions", "-Dthrow=abort" };
    libclipper2.linkLibC();
    libclipper2.linkSystemLibrary("c++");
    libclipper2.addIncludePath(b.path("lib/clipper2/CPP/Clipper2Lib"));
    libclipper2.addIncludePath(b.path("src"));
    libclipper2.addCSourceFile(.{
        .file = b.path("lib/clipper2/CPP/Clipper2Lib/clipper.engine.cpp"),
        .flags = &libclipper2_flags,
    });
    libclipper2.addCSourceFile(.{
        .file = b.path("lib/clipper2/CPP/Clipper2Lib/clipper.offset.cpp"),
        .flags = &libclipper2_flags,
    });
    libclipper2.addCSourceFile(.{
        .file = b.path("src/clipperwrapper.cpp"),
        .flags = &libclipper2_flags,
    });

    const libgingerbread = b.addExecutable(.{ .name = "gingerbread", .root_source_file = b.path("src/gingerbread.zig"), .version = .{ .major = 1, .minor = 0, .patch = 0 }, .target = target, .optimize = optimize, .strip = true });
    libgingerbread.entry = .disabled;
    libgingerbread.rdynamic = true;
    libgingerbread.wasi_exec_model = std.builtin.WasiExecModel.reactor;
    libgingerbread.linkLibC();
    libgingerbread.linkLibrary(libpotrace);
    libgingerbread.linkLibrary(libclipper2);
    libgingerbread.addIncludePath(b.path("src"));
    libgingerbread.addIncludePath(b.path("lib/potrace-1.16/src"));

    b.installArtifact(libgingerbread);

    // const main = b.addTest(.{
    //     .name = "main",
    //     .root_source_file = b.path("src/tests.zig"),
    //     .target = target,
    //     .optimize = optimize,
    //     .link_libc = true,
    // });
    // main.linkLibrary(libpotrace);
    // main.linkLibrary(libclipper2);
    // main.addIncludePath(b.path("src/"));
    // main.addIncludePath(b.path("lib/potrace-1.16/src"));
    // main.addIncludePath(b.path("lib/potrace-config"));
    // main.addIncludePath(b.path("lib/stb"));
    // main.addCSourceFile(.{ .file = b.path("src/load_image.c"), .flags = &.{
    //     "-std=gnu17",
    // } });

    // //main.install();

    // const test_step = b.step("test", "Test the program");
    // test_step.dependOn(&main.step);
    // b.default_step.dependOn(test_step);
}
