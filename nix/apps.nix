_: {
  perSystem =
    { config, ... }:
    {
      apps.dwl = {
        type = "app";
        program = "${config.packages.dwl}/bin/dwl";
      };
      apps.default = config.apps.dwl;
    };
}
