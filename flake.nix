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
        "x86-64_linux"
        "aarch64-linux"
      ];
    });
}
