const std = @import("std");
const builtin = @import("builtin");

pub fn linkOpenSsl(
    b: *std.Build,
    compile: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    openssl_prefix: ?[]const u8,
    link_openssl: bool,
) void {
    const mod = compile.root_module;
    const is_windows = target.result.os.tag == .windows;

    if (is_windows) {
        mod.addIncludePath(b.path("third_party/openssl/include"));
        mod.addObjectFile(b.path("third_party/openssl/lib/libcrypto.lib"));
        mod.addObjectFile(b.path("third_party/openssl/lib/libssl.lib"));
        mod.addObjectFile(b.path("third_party/win64/ws2_32.lib"));
        mod.addObjectFile(b.path("third_party/win64/crypt32.lib"));
        mod.addObjectFile(b.path("third_party/win64/cryptui.lib"));
        if (target.result.abi == .gnu) {
            mod.linkSystemLibrary("rstrtmgr", .{});
        } else {
            mod.addObjectFile(b.path("third_party/win64/RstrtMgr.lib"));
        }
        compile.step.dependOn(&b.addInstallFileWithDir(
            b.path("third_party/openssl/lib/libssl-3-x64.dll"),
            .bin,
            "libssl-3-x64.dll",
        ).step);
        compile.step.dependOn(&b.addInstallFileWithDir(
            b.path("third_party/openssl/lib/libcrypto-3-x64.dll"),
            .bin,
            "libcrypto-3-x64.dll",
        ).step);
        return;
    }

    if (!link_openssl) return;

    if (target.result.os.tag == .linux or builtin.os.tag == .linux) {
        mod.addIncludePath(b.path("third_party/openssl/include"));
        mod.linkSystemLibrary("ssl", .{});
        mod.linkSystemLibrary("crypto", .{});
        return;
    }

    if (target.result.os.tag == .macos or builtin.os.tag == .macos) {
        const prefix = openssl_prefix orelse "/opt/homebrew/opt/openssl@3";
        mod.addIncludePath(b.path(b.fmt("{s}/include", .{prefix})));
        mod.addLibraryPath(b.path(b.fmt("{s}/lib", .{prefix})));
        mod.linkSystemLibrary("ssl", .{});
        mod.linkSystemLibrary("crypto", .{});
    }
}
