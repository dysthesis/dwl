{ self, ... }:
{
  perSystem = { config, pkgs, lib, system, ... }: {
    packages.dwl = pkgs.callPackage ./pkgs/dwl.nix { };
    packages.default = config.packages.dwl;
  };
}

