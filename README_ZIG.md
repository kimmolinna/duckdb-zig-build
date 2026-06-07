# Building DuckDB with Zig

This fork provides a Zig-based alternative to the CMake build. It targets **Zig 0.14+** (tested with Zig 0.17).

## Prerequisites

### Linux (Ubuntu/Debian)

```bash
sudo apt-get install python3 clang lld llvm cmake libssl-dev zlib1g-dev
```

Install Zig from [ziglang.org/download](https://ziglang.org/download/) or via [zvm](https://github.com/jakubboni/zvm).

### macOS

```bash
brew install llvm openssl@3
```

Use `-Dopenssl-prefix=$(brew --prefix openssl@3)` when linking OpenSSL.

## Quick start

```bash
# Shared library (all in-tree CI extensions)
zig build -Doptimize=ReleaseFast

# Minimal build (core_functions + parquet only)
zig build -Doptimize=ReleaseFast -Dminimal=true

# DuckDB CLI
zig build --build-file build_shell.zig -Doptimize=ReleaseFast

# Windows cross-compile (DLL, default)
zig build --build-file build_win.zig -Doptimize=ReleaseFast -Dtarget=x86_64-windows-gnu

# Windows static libs (duckdb_static + extensions)
zig build --build-file build_win.zig -Doptimize=ReleaseFast -Dtarget=x86_64-windows-gnu -Dmode=libs

# Windows cross-compile (CLI)
zig build --build-file build_win.zig -Doptimize=ReleaseFast -Dtarget=x86_64-windows-gnu -Dmode=shell

# Faster CI-style minimal Windows build
zig build --build-file build_win.zig -Doptimize=ReleaseFast -Dminimal=true -Dtarget=x86_64-windows-gnu -Dmode=dll
```

Artifacts install to `zig-out/`.

## Build options

| Option | Description |
|--------|-------------|
| `-Doptimize=ReleaseFast` | Optimized release build |
| `-Dminimal=true` | Only `core_functions` and `parquet` extensions |
| `-Dopenssl-prefix=PATH` | OpenSSL prefix on macOS |
| `-Dlink-openssl=true` | Link system OpenSSL (optional; httpfs loads at runtime) |
| `-Dmode=libs\|dll\|shell` | Windows build mode (`build_win.zig`) |

## Syncing with upstream

```bash
git fetch upstream --tags
git merge upstream/main
```

Resolve conflicts while preserving Zig-specific files: `build*.zig`, `build/`, `README_ZIG.md`, `flake.nix`.

## Extensions

The default Zig build includes the same in-tree extensions as upstream CI:

- `autocomplete`, `core_functions`, `icu`, `json`, `parquet`, `tpcds`, `tpch`

`httpfs` is **out-of-tree** in modern DuckDB and is loaded via autoload at runtime, not compiled in.

## Testing

The Zig build does **not** compile DuckDB's full `test/` suite. Upstream tests are a single `unittest` binary (Catch2 + SQLLogic) that runs thousands of `.test` files — that infrastructure is owned by CMake/Make.

### Smoke tests (Zig build validation)

After building, verify the CLI with a few quick queries:

```bash
zig build --build-file build_shell.zig -Doptimize=ReleaseFast

./zig-out/bin/duckdb -c "SELECT 1"
./zig-out/bin/duckdb -c "SELECT version()"
./zig-out/bin/duckdb -c "SELECT json_extract('{\"a\":42}', '$.a')"

# Parquet roundtrip
./zig-out/bin/duckdb -c "
  COPY (SELECT 1 AS id, 'hello' AS msg) TO '/tmp/smoke.parquet' (FORMAT parquet);
  SELECT * FROM read_parquet('/tmp/smoke.parquet');
"

# Loaded extensions (full build)
./zig-out/bin/duckdb -c "SELECT extension_name FROM duckdb_extensions() WHERE loaded ORDER BY 1"
```

Minimal build (`-Dminimal=true`) should load only `core_functions` and `parquet`; `json_extract` should suggest loading the json extension.

CI runs a subset of this via `.github/workflows/ZigBuild.yml` (`SELECT 1` after a minimal shell build).

### Full regression (CMake)

For upstream-parity testing, use the standard DuckDB test runner:

```bash
make release
make unittest_release

# Or run a single SQLLogic file:
build/release/test/unittest test/sql/copy/parquet/parquet_basic.test
```

No `build_unittest.zig` is provided — duplicating the entire `test/` tree in Zig would be high maintenance with little benefit for this fork.

## Nix development shell

```bash
nix develop -c $SHELL
zig build -Doptimize=ReleaseFast
```

## Project layout

```
build.zig           # libduckdb shared library
build_shell.zig     # duckdb CLI
build_win.zig       # Windows cross-compile
build/
  duckdb.zig        # shared helpers
  extensions.zig    # extension definitions
  third_party.zig   # vendored libraries
  openssl.zig       # platform OpenSSL linking
  duckdb_lib.zig    # duckdb static/shared library logic
  shell.zig         # shared shell/linenoise setup
```
