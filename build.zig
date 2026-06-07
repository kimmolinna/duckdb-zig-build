const std = @import("std");
const duckdb_lib = @import("build/duckdb_lib.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const minimal = b.option(bool, "minimal", "Build with only core_functions and parquet") orelse false;
    const openssl_prefix = b.option([]const u8, "openssl-prefix", "OpenSSL install prefix (macOS)") orelse null;
    const link_openssl = b.option(bool, "link-openssl", "Link system OpenSSL (optional, for httpfs autoload)") orelse false;

    _ = try duckdb_lib.buildSharedLib(b, target, optimize, .{
        .minimal = minimal,
        .openssl_prefix = openssl_prefix,
        .link_openssl = link_openssl,
    });
}
