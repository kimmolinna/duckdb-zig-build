const std = @import("std");

pub const shell_sources = [_][]const u8{
    "tools/shell/shell.cpp",
    "tools/shell/shell_command_line_option.cpp",
    "tools/shell/shell_extension.cpp",
    "tools/shell/shell_helpers.cpp",
    "tools/shell/shell_metadata_command.cpp",
    "tools/shell/shell_prompt.cpp",
    "tools/shell/shell_renderer.cpp",
    "tools/shell/shell_highlight.cpp",
    "tools/shell/shell_progress_bar.cpp",
    "tools/shell/shell_render_table_metadata.cpp",
    "tools/shell/shell_windows.cpp",
};

pub const linenoise_sources = [_][]const u8{
    "tools/shell/linenoise/linenoise-c.cpp",
    "tools/shell/linenoise/linenoise.cpp",
    "tools/shell/linenoise/highlighting.cpp",
    "tools/shell/linenoise/history.cpp",
    "tools/shell/linenoise/rendering.cpp",
    "tools/shell/linenoise/terminal.cpp",
};

pub fn configureModule(
    b: *std.Build,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
) void {
    _ = target;
    for (shell_sources) |src| {
        mod.addCSourceFile(.{ .file = b.path(src), .flags = &.{} });
    }
    for (linenoise_sources) |src| {
        mod.addCSourceFile(.{ .file = b.path(src), .flags = &.{} });
    }
    mod.addIncludePath(b.path("tools/shell/include"));
    mod.addIncludePath(b.path("tools/shell/linenoise/include"));
    mod.addIncludePath(b.path("third_party/utf8proc/include"));
    mod.addCMacro("HAVE_LINENOISE", "1");
    mod.addCMacro("USE_DUCKDB_SHELL_WRAPPER", "");
}
