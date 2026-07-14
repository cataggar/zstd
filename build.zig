const std = @import("std");

const version = std.SemanticVersion{ .major = 1, .minor = 6, .patch = 0 };

const library_sources = &.{
    "lib/common/debug.c",
    "lib/common/entropy_common.c",
    "lib/common/error_private.c",
    "lib/common/fse_decompress.c",
    "lib/common/pool.c",
    "lib/common/threading.c",
    "lib/common/xxhash.c",
    "lib/common/zstd_common.c",
    "lib/compress/fse_compress.c",
    "lib/compress/hist.c",
    "lib/compress/huf_compress.c",
    "lib/compress/zstd_compress.c",
    "lib/compress/zstd_compress_literals.c",
    "lib/compress/zstd_compress_sequences.c",
    "lib/compress/zstd_compress_superblock.c",
    "lib/compress/zstd_double_fast.c",
    "lib/compress/zstd_fast.c",
    "lib/compress/zstd_lazy.c",
    "lib/compress/zstd_ldm.c",
    "lib/compress/zstd_opt.c",
    "lib/compress/zstd_preSplit.c",
    "lib/compress/zstdmt_compress.c",
    "lib/decompress/huf_decompress.c",
    "lib/decompress/huf_decompress_amd64.S",
    "lib/decompress/zstd_ddict.c",
    "lib/decompress/zstd_decompress.c",
    "lib/decompress/zstd_decompress_block.c",
    "lib/dictBuilder/cover.c",
    "lib/dictBuilder/divsufsort.c",
    "lib/dictBuilder/fastcover.c",
    "lib/dictBuilder/zdict.c",
};

const cli_sources = &.{
    "programs/benchfn.c",
    "programs/benchzstd.c",
    "programs/datagen.c",
    "programs/dibio.c",
    "programs/fileio.c",
    "programs/fileio_asyncio.c",
    "programs/lorem.c",
    "programs/timefn.c",
    "programs/util.c",
    "programs/zstdcli.c",
    "programs/zstdcli_trace.c",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const shared = b.option(bool, "shared", "Build libzstd as a shared library") orelse false;
    const multithread = b.option(bool, "multithread", "Enable multithreaded compression") orelse true;

    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .pic = true,
    });
    configureModule(b, lib_mod, multithread);
    lib_mod.addCSourceFiles(.{
        .files = library_sources,
        .flags = &.{"-std=c99"},
    });

    const lib = b.addLibrary(.{
        .name = "zstd",
        .linkage = if (shared) .dynamic else .static,
        .root_module = lib_mod,
        .version = version,
    });
    lib.installHeader(b.path("lib/zstd.h"), "zstd.h");
    lib.installHeader(b.path("lib/zstd_errors.h"), "zstd_errors.h");
    lib.installHeader(b.path("lib/zdict.h"), "zdict.h");
    b.installArtifact(lib);

    const exe_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    configureModule(b, exe_mod, multithread);
    exe_mod.addIncludePath(b.path("programs"));
    exe_mod.addCSourceFiles(.{
        .files = cli_sources,
        .flags = &.{"-std=c99"},
    });
    exe_mod.linkLibrary(lib);

    const exe = b.addExecutable(.{
        .name = "zstd",
        .root_module = exe_mod,
        .version = version,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the zstd command-line utility");
    run_step.dependOn(&run_cmd.step);
}

fn configureModule(b: *std.Build, module: *std.Build.Module, multithread: bool) void {
    module.addIncludePath(b.path("lib"));
    module.addCMacro("DEBUGLEVEL", "0");
    module.addCMacro("XXH_NAMESPACE", "ZSTD_");
    module.addCMacro("ZSTD_LEGACY_SUPPORT", "0");

    if (multithread) {
        module.addCMacro("ZSTD_MULTITHREAD", "1");
        if (module.resolved_target.?.result.os.tag != .windows) {
            module.linkSystemLibrary("pthread", .{});
        }
    }
}
