{
  description = "Patching nixpkgs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-patched.url = "github:dtomvan/nixpkgs/nixos-unstable-patched";

    # nixos/forgejo-runner: init module
    nixpkgs-patch-10 = {
      url = "https://github.com/dtomvan/nixpkgs/commit/7488a70e4a522236091ddf0d108ac0e7e6febfc0.patch";
      flake = false;
    };

    # matrix-continuwuity: 0.5.10 -> 26.6.0
    nixpkgs-patch-20 = {
      url = "https://github.com/nixos/nixpkgs/commit/59fe8116c3606fd4e50aa5dda343de448d134fb2.patch";
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
