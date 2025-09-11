{
  description = "dwl";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ flake-parts, systems, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (_: {
      imports = [
        ./nix/packages.nix
        ./nix/devshells.nix
        ./nix/apps.nix
        ./nix/checks.nix
      ];
      systems = import systems;
    });
}
