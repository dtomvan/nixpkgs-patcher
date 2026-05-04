{
  description = "Patching nixpkgs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-patched.url = "github:dtomvan/nixpkgs/nixos-unstable-patched";

    # incus: 6.23.0 -> 7.0.0; incus-lts: 6.0.6-unstable-2026-03-27 -> 7.0.0
    nixpkgs-patch-10 = {
      url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/515853.diff";
      flake = false;
    };

    # nix: 2.34.6 -> 2.34.7
    nixpkgs-patch-20 = {
      url = "https://github.com/NixOS/nixpkgs/pull/516608.diff";
      flake = false;
    };

    # lix_2_9{4,5}: 2.9{4,5}.1 -> 2.9{4,5}.2
    nixpkgs-patch-30 = {
      url = "https://github.com/NixOS/nixpkgs/pull/516590.diff";
      flake = false;
    };

    # lix_2_94: fix build
    nixpkgs-patch-31 = {
      url = "https://github.com/NixOS/nixpkgs/commit/978725b29ecb9438982f0a6da5617b99c39de7a4.patch"
      flake = false;
    };

    # lix depends on this, required for caching
    nixpkgs-patch-40 = {
      url = "https://github.com/NixOS/nixpkgs/commit/c6d63f1ec80102dd3fa4122b31aa31005db43d25.patch";
      flake = false;
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    nix-patcher = {
      url = "github:katrinafyi/nix-patcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      perSystem =
        {
          pkgs,
          lib,
          self',
          inputs',
          ...
        }:
        {
          packages.default = pkgs.callPackage (
            {
              lib,
              writeShellApplication,
              opts ? { },
            }:
            writeShellApplication {
              name = "nix-patcher";
              runtimeInputs = lib.singleton inputs'.nix-patcher.packages.default;
              text = ''
                nix-patcher ${
                  lib.cli.toCommandLineShellGNU { } (
                    {
                      flake = ".";
                      commit = true;
                      patched-suffix = "-patched";
                      upstream-suffix = "";
                    }
                    // opts
                  )
                }
              '';
            }
          ) { };
          devShells.default = pkgs.mkShellNoCC {
            packages = lib.singleton self'.packages.default;
            shellHook = ''
              # intentionally print auth status so the user knows how they are
              # logged in and where they will patch their nixpkgs to
              if type -a gh 2>&1 >/dev/null && gh auth status; then
                export GITHUB_TOKEN="$(gh auth token)"
              fi
            '';
          };
        };
    };
}
