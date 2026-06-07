const std = @import("std");

pub const excluded_files = [_][]const u8{
    "grammar.cpp",
    "symbols.cpp",
    "os_win.c",
    "linenoise.cpp",
    "parquetcli.cpp",
    "utf8proc_data.cpp",
    "test_sqlite3_api_wrapper.cpp",
};

pub const allowed_exts = [_][]const u8{ ".c", ".cpp", ".cxx", ".c++", ".cc" };

pub const basic_include_dirs = [_][]const u8{
    "src/include",
    "extension",
    "third_party/concurrentqueue",
    "third_party/fast_float",
    "third_party/fastpforlib",
    "third_party/fmt/include",
    "third_party/fsst",
    "third_party/hyperloglog",
    "third_party/jaro_winkler",
    "third_party/mbedtls/include",
    "third_party/miniparquet",
    "third_party/miniz",
    "third_party/pcg",
    "third_party/pdqsort",
    "third_party/re2",
    "third_party/ska_sort",
    "third_party/skiplist",
    "third_party/tdigest",
    "third_party/utf8proc/include",
    "third_party/yyjson/include",
    "third_party/vergesort",
    "third_party/httplib",
};

pub fn generateVersion(b: *std.Build) !void {
    const run = b.addSystemCommand(&.{ "python3", "scripts/generate_version_hpp.py" });
    b.getInstallStep().dependOn(&run.step);
}

pub fn iterateFiles(b: *std.Build, path: []const u8) ![]const []const u8 {
    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(b.allocator);
    var dir = try b.root.root_dir.handle.openDir(b.graph.io, path, .{ .iterate = true });
    defer dir.close(b.graph.io);
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();
    var out: [512]u8 = undefined;
    while (try walker.next(b.graph.io)) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const include_file = for (allowed_exts) |e| {
            if (std.mem.eql(u8, ext, e)) break true;
        } else false;
        if (!include_file) continue;
        const exclude_file = for (excluded_files) |e| {
            if (std.mem.eql(u8, entry.basename, e)) break true;
        } else false;
        if (exclude_file) continue;
        const file = try std.fmt.bufPrint(&out, "{s}/{s}", .{ path, entry.path });
        try files.append(b.allocator, b.dupe(file));
    }
    return files.toOwnedSlice(b.allocator);
}

pub fn createCppModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    addBasicIncludes(b, mod);
    mod.addCMacro("DUCKDB_BUILD_LIBRARY", "");
    mod.pic = true;
    mod.strip = true;
    return mod;
}

pub fn addBasicIncludes(b: *std.Build, mod: *std.Build.Module) void {
    for (basic_include_dirs) |dir| {
        mod.addIncludePath(b.path(dir));
    }
}

pub fn addStaticLib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
) struct { mod: *std.Build.Module, lib: *std.Build.Step.Compile } {
    const mod = createCppModule(b, target, optimize);
    const lib = b.addLibrary(.{
        .name = name,
        .root_module = mod,
        .linkage = .static,
    });
    b.installArtifact(lib);
    return .{ .mod = mod, .lib = lib };
}
