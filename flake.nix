{
  description = "dwl";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (_: {
      imports = [
        ./nix/packages.nix
        ./nix/devshells.nix
        ./nix/apps.nix
        ./nix/checks.nix
      ];
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    });
}
