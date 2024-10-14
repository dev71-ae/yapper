{
  description = "dev71/yapper: An implementation of the Yap protocol in Zig.";

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
              inherit (pkgs) zig zls cargo cargo-zigbuild;
            }
            ++ l.optional pkgs.stdenv.isDarwin [pkgs.libiconv];

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
