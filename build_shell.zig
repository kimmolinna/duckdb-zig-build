const std = @import("std");
const duckdb = @import("build/duckdb.zig");
const duckdb_lib = @import("build/duckdb_lib.zig");
const openssl = @import("build/openssl.zig");
const shell = @import("build/shell.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const minimal = b.option(bool, "minimal", "Build with only core_functions and parquet") orelse false;
    const openssl_prefix = b.option([]const u8, "openssl-prefix", "OpenSSL install prefix (macOS)") orelse null;
    const link_openssl = b.option(bool, "link-openssl", "Link system OpenSSL (optional)") orelse false;

    const artifacts = try duckdb_lib.buildDuckDb(b, target, optimize, .{
        .minimal = minimal,
        .openssl_prefix = openssl_prefix,
        .link_openssl = link_openssl,
    });

    const mod = duckdb.createCppModule(b, target, optimize);
    shell.configureModule(b, mod, target);
    mod.link_libc = true;
    mod.linkLibrary(artifacts.duckdb_static);
    mod.linkLibrary(artifacts.third_party_libs.utf8proc);

    const exe = b.addExecutable(.{ .name = "duckdb", .root_module = mod });
    openssl.linkOpenSsl(b, exe, target, openssl_prefix, link_openssl);
    b.installArtifact(exe);
}
