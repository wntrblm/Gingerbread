const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const rel_opts = b.standardReleaseOptions();
    const target: std.zig.CrossTarget = .{ .cpu_arch = .wasm32, .os_tag = .wasi };
    //const target = b.standardTargetOptions(.{});

    const libpotrace = b.addStaticLibrary("potrace", null);
    const libpotrace_flags = [_][]const u8{"-std=gnu17", "-DHAVE_CONFIG_H"};
    libpotrace.setTarget(target);
    libpotrace.setBuildMode(rel_opts);
    libpotrace.linkSystemLibrary("c");
    libpotrace.addIncludePath("lib/potrace-1.16/src");
    libpotrace.addIncludePath("lib/potrace-config");
    libpotrace.addCSourceFile("lib/potrace-1.16/src/curve.c", &libpotrace_flags);
    libpotrace.addCSourceFile("lib/potrace-1.16/src/trace.c", &libpotrace_flags);
    libpotrace.addCSourceFile("lib/potrace-1.16/src/decompose.c", &libpotrace_flags);
    libpotrace.addCSourceFile("lib/potrace-1.16/src/potracelib.c", &libpotrace_flags);

    const libclipper2 = b.addStaticLibrary("clipper2", null);
    const libclipper2_flags = [_][]const u8{"-std=gnu++17", "-fno-exceptions", "-Dthrow=abort"};
    libclipper2.setTarget(target);
    libclipper2.setBuildMode(rel_opts);
    libclipper2.linkSystemLibrary("c++");
    libclipper2.addIncludePath("lib/clipper2/CPP/Clipper2Lib");
    libclipper2.addIncludePath("src");
    libclipper2.addCSourceFile("lib/clipper2/CPP/Clipper2Lib/clipper.engine.cpp", &libclipper2_flags);
    libclipper2.addCSourceFile("lib/clipper2/CPP/Clipper2Lib/clipper.offset.cpp", &libclipper2_flags);
    libclipper2.addCSourceFile("src/clipperwrapper.cpp", &libclipper2_flags);

    if (target.cpu_arch != null and target.cpu_arch.? == .wasm32) {
        const libgingerbread = b.addSharedLibrary("gingerbread", "src/gingerbread.zig", b.version(1, 0, 0));
        libgingerbread.wasi_exec_model = std.builtin.WasiExecModel.reactor;
        libgingerbread.setBuildMode(rel_opts);
        libgingerbread.setTarget(target);
        libgingerbread.linkSystemLibrary("c");
        libgingerbread.linkLibrary(libpotrace);
        libgingerbread.linkLibrary(libclipper2);
        libgingerbread.addIncludePath("src");
        libgingerbread.addIncludePath("lib/potrace-1.16/src");

        libgingerbread.install();
    }

    const main = b.addTest("src/tests.zig");
    main.setBuildMode(rel_opts);
    main.setTarget(target);
    main.linkSystemLibrary("c");
    main.linkLibrary(libpotrace);
    main.linkLibrary(libclipper2);
    main.addIncludePath("src/");
    main.addIncludePath("lib/potrace-1.16/src");
    main.addIncludePath("lib/potrace-config");
    main.addIncludePath("lib/stb");
    main.addCSourceFile("src/load_image.c", &[_][]const u8{"-std=gnu17",});

    //main.install();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&main.step);
    b.default_step.dependOn(test_step);
}
