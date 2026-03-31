_: {
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      configLib = import ./lib/config-h.nix { inherit (pkgs) lib; };
      generatedConfigH = pkgs.writeText "config.h" (configLib.generate { spec = configLib.defaultSpec; });
      dwlPackage = pkgs.callPackage ./pkgs/dwl.nix { };
    in
    {
      packages = {
        dwl = dwlPackage;
        config-h = generatedConfigH;
        default = dwlPackage;
      };
    };
}
