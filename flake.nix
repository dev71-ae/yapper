{
  description = "A playground for Dev71 experimentation";

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {
        l,
        pkgs,
        ...
      }: {
        devShells.default = pkgs.mkShell {
          packages =
            l.attrValues {
              inherit (pkgs) zig zls cargo openssl pkg-config;
            }
            ++ l.optional pkgs.stdenv.isDarwin [pkgs.libiconv];

          shellHook = ''
            # We unset some NIX environment variables that might interfere with the zig
            # compiler.
            # Issue: https://github.com/ziglang/zig/issues/18998
            unset NIX_CFLAGS_COMPILE
            #unset NIX_LDFLAGS
          '';

          OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
          BORINGSSL_LIB_DIR = "${pkgs.boringssl}/lib";
        };
      };
      imports = [{perSystem = {lib, ...}: {_module.args.l = lib // builtins;};}];
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
}
