{
  description = "dev71/yapper: An implementation of the Yap protocol.";

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {
        pkgs,
        lib,
        inputs',
        ...
      }: let
        toolchain = (inputs'.fenix.packages).fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "yMuSb5eQPO/bHv+Bcf/US8LVMbf/G/0MSfiPwBhiPpk=";
        };
      in {
        devShells.default = pkgs.mkShell {
          packages =
            builtins.attrValues {
              inherit toolchain;
            }
            ++ lib.optionals pkgs.stdenv.isDarwin [pkgs.libiconv];

          BORINGSSL_LIB_DIR = "${pkgs.boringssl}/lib";
        };
      }; # perSystem
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
