const std = @import("std");
const duckdb = @import("duckdb.zig");
const extensions = @import("extensions.zig");
const third_party = @import("third_party.zig");
const openssl = @import("openssl.zig");

pub const Options = struct {
    minimal: bool = false,
    openssl_prefix: ?[]const u8 = null,
    link_openssl: bool = false,
};

pub const DuckDbArtifacts = struct {
    duckdb_static: *std.Build.Step.Compile,
    third_party_libs: third_party.ThirdPartyLibs,
    extension_libs: extensions.ExtensionLibs,
};

fn extList(opts: Options) []const extensions.Extension {
    return if (opts.minimal) &extensions.minimal_extensions else &extensions.ci_extensions;
}

pub fn buildDuckDb(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    opts: Options,
) !DuckDbArtifacts {
    try duckdb.generateVersion(b);

    const list = extList(opts);
    const tp = try third_party.buildThirdPartyLibs(b, target, optimize);
    const ext_libs = try extensions.buildExtensionLibs(b, target, optimize, list);
    const generated = try extensions.generateExtensionLoader(b, list);

    const artifact = duckdb.addStaticLib(b, target, optimize, "duckdb_static");
    const duckdb_sources = try duckdb.iterateFiles(b, "src");
    artifact.mod.addCSourceFiles(.{ .files = duckdb_sources });
    artifact.lib.step.dependOn(generated.step);
    artifact.mod.addCSourceFile(.{ .file = generated.source, .flags = &.{} });
    extensions.addExtensionIncludes(b, artifact.mod, list);
    extensions.addExtensionMacros(artifact.mod, list);
    artifact.mod.addCMacro("DUCKDB_MAIN_LIBRARY", "");
    artifact.mod.addCMacro("DUCKDB", "");
    openssl.linkOpenSsl(b, artifact.lib, target, opts.openssl_prefix, opts.link_openssl);
    tp.linkAll(artifact.mod);
    for (ext_libs.libs) |ext_lib| {
        artifact.mod.linkLibrary(ext_lib);
    }
    artifact.mod.link_libc = true;

    return .{
        .duckdb_static = artifact.lib,
        .third_party_libs = tp,
        .extension_libs = ext_libs,
    };
}

pub fn buildSharedLib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    opts: Options,
) !*std.Build.Step.Compile {
    try duckdb.generateVersion(b);

    const list = extList(opts);
    const tp = try third_party.buildThirdPartyLibs(b, target, optimize);
    const ext_libs = try extensions.buildExtensionLibs(b, target, optimize, list);
    const generated = try extensions.generateExtensionLoader(b, list);

    const mod = duckdb.createCppModule(b, target, optimize);
    const duckdb_sources = try duckdb.iterateFiles(b, "src");
    mod.addCSourceFiles(.{ .files = duckdb_sources });
    mod.addCSourceFile(.{ .file = generated.source, .flags = &.{} });
    extensions.addExtensionIncludes(b, mod, list);
    extensions.addExtensionMacros(mod, list);
    mod.addCMacro("DUCKDB_MAIN_LIBRARY", "");
    mod.addCMacro("DUCKDB", "");
    mod.link_libc = true;

    const shared = b.addLibrary(.{
        .name = "duckdb",
        .root_module = mod,
        .linkage = .dynamic,
    });
    shared.step.dependOn(generated.step);
    openssl.linkOpenSsl(b, shared, target, opts.openssl_prefix, opts.link_openssl);
    tp.linkAll(mod);
    for (ext_libs.libs) |ext_lib| {
        mod.linkLibrary(ext_lib);
    }
    b.installArtifact(shared);
    return shared;
}
