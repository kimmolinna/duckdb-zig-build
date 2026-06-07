const std = @import("std");
const duckdb = @import("build/duckdb.zig");
const duckdb_lib = @import("build/duckdb_lib.zig");
const openssl = @import("build/openssl.zig");
const shell = @import("build/shell.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .gnu,
        },
    });
    const optimize = b.standardOptimizeOption(.{});
    const minimal = b.option(bool, "minimal", "Build with only core_functions and parquet") orelse false;
    const mode = b.option(enum { libs, dll, shell }, "mode", "Windows build mode") orelse .dll;
    const lib_opts = duckdb_lib.Options{
        .minimal = minimal,
        .openssl_prefix = null,
        .link_openssl = false,
    };

    switch (mode) {
        .libs => {
            _ = try duckdb_lib.buildDuckDb(b, target, optimize, lib_opts);
        },
        .dll => {
            _ = try duckdb_lib.buildSharedLib(b, target, optimize, lib_opts);
        },
        .shell => {
            const artifacts = try duckdb_lib.buildDuckDb(b, target, optimize, lib_opts);
            const mod = duckdb.createCppModule(b, target, optimize);
            shell.configureModule(b, mod, target);
            mod.link_libc = true;
            mod.linkLibrary(artifacts.duckdb_static);
            mod.linkLibrary(artifacts.third_party_libs.utf8proc);

            const exe = b.addExecutable(.{ .name = "duckdb", .root_module = mod });
            openssl.linkOpenSsl(b, exe, target, null, false);
            b.installArtifact(exe);
        },
    }
}
