{
  description = "Nix flake for duckdb-zig-build";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = {
    flake-utils,
    zig,
    nixpkgs,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          zig.overlays.default
        ];
      };
    in {
      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        packages = with pkgs;
          [
            cmake
            libxml2
            ninja
            openssl
            python3
            qemu
            zlib
            pkgs.zigpkgs."0.14.0"
          ]
          ++ (with llvmPackages_18; [
            clang
            clang-unwrapped
            lld
            llvm
          ]);
      };
    });
  in
    outputs;
}
