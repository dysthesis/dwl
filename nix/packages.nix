_: {
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      packages.dwl = pkgs.callPackage ./pkgs/dwl.nix { };
      packages.default = config.packages.dwl;
    };
}
