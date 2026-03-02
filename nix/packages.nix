_: {
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      configLib = import ./lib/config-h.nix { lib = pkgs.lib; };
      generatedConfigH = pkgs.writeText "config.h" (configLib.generate { spec = configLib.defaultSpec; });
    in
    {
      packages.dwl = pkgs.callPackage ./pkgs/dwl.nix { };
      packages.config-h = generatedConfigH;
      packages.default = config.packages.dwl;
    };
}
