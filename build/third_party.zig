const std = @import("std");
const duckdb = @import("duckdb.zig");

pub const ThirdPartyLibs = struct {
    fastpforlib: *std.Build.Step.Compile,
    fmt: *std.Build.Step.Compile,
    fsst: *std.Build.Step.Compile,
    hyperloglog: *std.Build.Step.Compile,
    mbedtls: *std.Build.Step.Compile,
    miniz: *std.Build.Step.Compile,
    re2: *std.Build.Step.Compile,
    skiplist: *std.Build.Step.Compile,
    utf8proc: *std.Build.Step.Compile,
    yyjson: *std.Build.Step.Compile,

    pub fn linkAll(self: ThirdPartyLibs, mod: *std.Build.Module) void {
        mod.linkLibrary(self.fastpforlib);
        mod.linkLibrary(self.fmt);
        mod.linkLibrary(self.fsst);
        mod.linkLibrary(self.hyperloglog);
        mod.linkLibrary(self.mbedtls);
        mod.linkLibrary(self.miniz);
        mod.linkLibrary(self.re2);
        mod.linkLibrary(self.skiplist);
        mod.linkLibrary(self.utf8proc);
        mod.linkLibrary(self.yyjson);
    }
};

pub fn buildThirdPartyLibs(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !ThirdPartyLibs {
    const specs = [_]struct { name: []const u8, path: []const u8, include: ?[]const u8 }{
        .{ .name = "fastpforlib", .path = "third_party/fastpforlib", .include = null },
        .{ .name = "fmt", .path = "third_party/fmt", .include = null },
        .{ .name = "fsst", .path = "third_party/fsst", .include = null },
        .{ .name = "hyperloglog", .path = "third_party/hyperloglog", .include = null },
        .{ .name = "mbedtls", .path = "third_party/mbedtls", .include = null },
        .{ .name = "miniz", .path = "third_party/miniz", .include = null },
        .{ .name = "re2", .path = "third_party/re2", .include = null },
        .{ .name = "skiplistlib", .path = "third_party/skiplist", .include = null },
        .{ .name = "utf8proc", .path = "third_party/utf8proc", .include = null },
        .{ .name = "yyjson", .path = "third_party/yyjson", .include = "third_party/yyjson/include" },
    };

    var built: [specs.len]*std.Build.Step.Compile = undefined;
    for (specs, 0..) |spec, i| {
        const artifact = duckdb.addStaticLib(b, target, optimize, spec.name);
        const files = try duckdb.iterateFiles(b, spec.path);
        artifact.mod.addCSourceFiles(.{ .files = files });
        if (spec.include) |inc| artifact.mod.addIncludePath(b.path(inc));
        built[i] = artifact.lib;
    }

    return .{
        .fastpforlib = built[0],
        .fmt = built[1],
        .fsst = built[2],
        .hyperloglog = built[3],
        .mbedtls = built[4],
        .miniz = built[5],
        .re2 = built[6],
        .skiplist = built[7],
        .utf8proc = built[8],
        .yyjson = built[9],
    };
}
