_: {
  perSystem =
    { config, ... }:
    {
      apps.dwl = {
        type = "app";
        program = "${config.packages.dwl}/bin/dwl";
        meta = {
          description = "Launch dwl (wlroots-based Wayland compositor)";
        };
      };
      apps.default = config.apps.dwl;
    };
}
