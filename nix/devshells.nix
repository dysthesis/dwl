_: {
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        name = "dwl";
        inputsFrom = [ config.packages.dwl ];
        nativeBuildInputs = with pkgs; [
          pkg-config
          gnumake
          git
        ];
        packages = with pkgs; [
          nixd
          nixfmt
          statix
          deadnix
        ];

      };
    };
}
