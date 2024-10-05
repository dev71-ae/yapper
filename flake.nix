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
              inherit (pkgs) zig zls cargo;
            }
            ++ l.optional pkgs.stdenv.isDarwin [pkgs.iconv];

          BORINGSSL_LIB_DIR = "${pkgs.boringssl}/lib";
        };
      };
      imports = [{perSystem = {lib, ...}: {_module.args.l = lib // builtins;};}];
    };

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
}
