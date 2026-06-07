const std = @import("std");
const duckdb = @import("duckdb.zig");

pub const Extension = struct {
    name: []const u8,
    class_name: []const u8,
    path: []const u8,
    extra_sources: []const []const u8 = &.{},
    extra_includes: []const []const u8 = &.{},
};

pub const minimal_extensions = [_]Extension{
    .{ .name = "core_functions", .class_name = "CoreFunctionsExtension", .path = "extension/core_functions" },
    .{ .name = "parquet", .class_name = "ParquetExtension", .path = "extension/parquet", .extra_sources = &.{
        "third_party/parquet",
        "third_party/snappy",
        "third_party/thrift",
        "third_party/zstd",
        "third_party/lz4",
        "third_party/brotli/common",
        "third_party/brotli/enc",
        "third_party/brotli/dec",
    }, .extra_includes = &.{
        "third_party/parquet",
        "third_party/snappy",
        "third_party/thrift",
        "third_party/zstd/include",
        "third_party/lz4",
        "third_party/brotli/include",
    } },
};

pub const ci_extensions = [_]Extension{
    .{ .name = "autocomplete", .class_name = "AutocompleteExtension", .path = "extension/autocomplete" },
    .{ .name = "core_functions", .class_name = "CoreFunctionsExtension", .path = "extension/core_functions" },
    .{ .name = "icu", .class_name = "IcuExtension", .path = "extension/icu", .extra_includes = &.{
        "extension/icu/third_party/icu/common",
        "extension/icu/third_party/icu/i18n",
    } },
    .{ .name = "json", .class_name = "JsonExtension", .path = "extension/json" },
    .{ .name = "parquet", .class_name = "ParquetExtension", .path = "extension/parquet", .extra_sources = &.{
        "third_party/parquet",
        "third_party/snappy",
        "third_party/thrift",
        "third_party/zstd",
        "third_party/lz4",
        "third_party/brotli/common",
        "third_party/brotli/enc",
        "third_party/brotli/dec",
    }, .extra_includes = &.{
        "third_party/parquet",
        "third_party/snappy",
        "third_party/thrift",
        "third_party/zstd/include",
        "third_party/lz4",
        "third_party/brotli/include",
    } },
    .{ .name = "tpcds", .class_name = "TpcdsExtension", .path = "extension/tpcds", .extra_includes = &.{
        "extension/tpcds/dsdgen/include",
        "extension/tpcds/dsdgen/include/dsdgen-c",
    } },
    .{ .name = "tpch", .class_name = "TpchExtension", .path = "extension/tpch", .extra_includes = &.{
        "extension/tpch/dbgen/include",
    } },
};

pub const ExtensionLibs = struct {
    libs: []const *std.Build.Step.Compile,
};

pub fn addExtensionMacros(mod: *std.Build.Module, extensions: []const Extension) void {
    for (extensions) |ext| {
        var macro_buf: [64]u8 = undefined;
        var upper_buf: [64]u8 = undefined;
        const upper = toUpper(ext.name, &upper_buf);
        const macro = std.fmt.bufPrint(&macro_buf, "DUCKDB_EXTENSION_{s}_LINKED", .{upper}) catch unreachable;
        mod.addCMacro(macro, "1");
    }
}

pub fn addExtensionIncludes(b: *std.Build, mod: *std.Build.Module, extensions: []const Extension) void {
    for (extensions) |ext| {
        mod.addIncludePath(b.path(b.fmt("{s}/include", .{ext.path})));
        for (ext.extra_includes) |inc| {
            mod.addIncludePath(b.path(inc));
        }
    }
}

pub fn buildExtensionLibs(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    ext_list: []const Extension,
) !ExtensionLibs {
    var libs: std.ArrayList(*std.Build.Step.Compile) = .empty;
    defer libs.deinit(b.allocator);
    for (ext_list) |ext| {
        const artifact = duckdb.addStaticLib(b, target, optimize, b.fmt("{s}_extension", .{ext.name}));
        const sources = try duckdb.iterateFiles(b, ext.path);
        artifact.mod.addCSourceFiles(.{ .files = sources });
        for (ext.extra_sources) |src_path| {
            const extra_files = try duckdb.iterateFiles(b, src_path);
            artifact.mod.addCSourceFiles(.{ .files = extra_files });
        }
        artifact.mod.addIncludePath(b.path(b.fmt("{s}/include", .{ext.path})));
        for (ext.extra_includes) |inc| {
            artifact.mod.addIncludePath(b.path(inc));
        }
        try libs.append(b.allocator, artifact.lib);
    }
    return .{ .libs = try libs.toOwnedSlice(b.allocator) };
}

pub fn generateExtensionLoader(
    b: *std.Build,
    ext_list: []const Extension,
) !struct { source: std.Build.LazyPath, step: *std.Build.Step } {
    var body_buf: std.ArrayList(u8) = .empty;
    defer body_buf.deinit(b.allocator);
    var names_buf: std.ArrayList(u8) = .empty;
    defer names_buf.deinit(b.allocator);

    for (ext_list, 0..) |ext, i| {
        try body_buf.appendSlice(b.allocator, try std.fmt.allocPrint(b.allocator,
            \\    if (extension=="{s}") {{
            \\        db.LoadStaticExtension<{s}>();
            \\        return ExtensionLoadResult::LOADED_EXTENSION;
            \\    }}
        , .{ ext.name, ext.class_name }));
        const prefix = if (i == 0) "\n\t" else ",\n\t";
        try names_buf.appendSlice(b.allocator, try std.fmt.allocPrint(b.allocator, "{s}\"{s}\"", .{ prefix, ext.name }));
    }

    var includes_buf: std.ArrayList(u8) = .empty;
    defer includes_buf.deinit(b.allocator);
    for (ext_list) |ext| {
        try includes_buf.appendSlice(b.allocator, try std.fmt.allocPrint(b.allocator, "#include \"{s}_extension.hpp\"\n", .{ext.name}));
    }

    var source_buf: std.ArrayList(u8) = .empty;
    defer source_buf.deinit(b.allocator);
    try source_buf.appendSlice(b.allocator, includes_buf.items);
    try source_buf.appendSlice(b.allocator,
        \\#include "duckdb/main/extension/generated_extension_loader.hpp"
        \\#include "duckdb/main/extension_helper.hpp"
        \\
        \\namespace duckdb {
        \\
        \\ExtensionLoadResult ExtensionHelper::LoadExtension(DuckDB &db, const std::string &extension) {
        \\
    );
    try source_buf.appendSlice(b.allocator, body_buf.items);
    try source_buf.appendSlice(b.allocator,
        \\    return ExtensionLoadResult::NOT_LOADED;
        \\}
        \\
        \\vector<string> LinkedExtensions(){
        \\    vector<string> VEC = {
        \\
    );
    try source_buf.appendSlice(b.allocator, names_buf.items);
    try source_buf.appendSlice(b.allocator,
        \\
        \\    };
        \\    return VEC;
        \\}
        \\
        \\void ExtensionHelper::LoadAllExtensions(DuckDB &db) {
        \\    for (auto& ext_name : LinkedExtensions()) {
        \\        LoadExtension(db, ext_name);
        \\    }
        \\}
        \\
        \\vector<string> ExtensionHelper::LoadedExtensionTestPaths(){
        \\    return {};
        \\}
        \\}
        \\
    );

    const write_files = b.addWriteFiles();
    const source_path = write_files.add(
        "generated_extension_loader.cpp",
        try source_buf.toOwnedSlice(b.allocator),
    );

    return .{
        .source = source_path,
        .step = &write_files.step,
    };
}

fn toUpper(name: []const u8, buf: *[64]u8) []const u8 {
    var i: usize = 0;
    for (name) |c| {
        buf[i] = if (c == '_') '_' else std.ascii.toUpper(c);
        i += 1;
    }
    return buf[0..i];
}
