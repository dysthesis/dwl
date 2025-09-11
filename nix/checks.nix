_: {
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      # Helper to gather common build inputs for C checks
      commonBuildInputs = with pkgs; [
        wayland
        (pkgs.wlroots_0_19 or pkgs.wlroots)
        libinput
        libxkbcommon
        pixman
        libdrm
        seatd
        wayland-protocols
      ];

      xDeps = with pkgs.xorg; [ libxcb xcbutilwm ];

      mkScanBuild = { enableXWayland ? false }: pkgs.stdenv.mkDerivation {
        pname = "dwl-scan-build-check";
        version = "1";
        src = pkgs.lib.cleanSource ../.;
        nativeBuildInputs = with pkgs; [
          pkg-config
          wayland-scanner
          clang
          clang-analyzer
          gnumake
        ];
        buildInputs = commonBuildInputs ++ pkgs.lib.optionals enableXWayland xDeps;
        dontConfigure = true;
        buildPhase = ''
          echo "Running clang-analyzer (scan-build) with status-bugs..."
          export CC=${pkgs.clang}/bin/clang
          export CXX=${pkgs.clang}/bin/clang++
          scan-build \
            --status-bugs \
            --use-cc="$CC" \
            --use-c++="$CXX" \
            -o "$TMPDIR/scan-report" \
            make WAYLAND_SCANNER=${pkgs.wayland-scanner.bin}/bin/wayland-scanner
        '';
        installPhase = ''
          mkdir -p $out
          # Preserve the analyzer HTML output if present; otherwise, just succeed
          if [ -d "$TMPDIR/scan-report" ]; then
            cp -r "$TMPDIR/scan-report" "$out/scan-report"
          else
            touch "$out/ok"
          fi
        '';
      };

      # Strict Clang build (treat warnings as errors)
      clangWerror = pkgs.callPackage ./pkgs/dwl.nix {
        stdenv = pkgs.clangStdenv;
      };

      # Strict GCC build with -fanalyzer
      gccFanalyzer = pkgs.callPackage ./pkgs/dwl.nix {
        stdenv = pkgs.gccStdenv;
      };
    in
    {
      checks = {
        # Build the default package (ensures normal build stays green)
        build = config.packages.dwl;

        # Build with XWayland support toggled on
        build-xwayland = pkgs.callPackage ./pkgs/dwl.nix {
          enableXWayland = true;
          xorg = pkgs.xorg;
        };

        # Clang analyzer via scan-build as a dedicated check (HTML report in result/scan-report)
        scan-build = mkScanBuild { enableXWayland = false; };

        # Extra-rigorous compiles
        clang-werror = clangWerror.overrideAttrs (prev: {
          NIX_CFLAGS_COMPILE = (prev.NIX_CFLAGS_COMPILE or "")
            + " -Werror -Wformat -Wformat-security -Wundef";
        });

        gcc-fanalyzer = gccFanalyzer.overrideAttrs (prev: {
          NIX_CFLAGS_COMPILE = (prev.NIX_CFLAGS_COMPILE or "")
            + " -fanalyzer -Werror -Wformat -Wformat-security";
        });

        # Nix code hygiene
        nixfmt = pkgs.runCommand "nixpkgs-fmt-check" {
          buildInputs = [ pkgs.nixpkgs-fmt pkgs.findutils ];
          src = pkgs.lib.cleanSource ../.;
        } ''
          echo "Checking Nix formatting with nixpkgs-fmt..."
          files=$(find "$src" -type f -name '*.nix')
          if [ -n "$files" ]; then
            nixpkgs-fmt --check $files
          fi
          touch $out
        '';

        statix = pkgs.runCommand "statix-check" {
          buildInputs = [ pkgs.statix ];
          src = pkgs.lib.cleanSource ../.;
        } ''
          echo "Running statix..."
          statix check "$src"
          touch $out
        '';

        deadnix = pkgs.runCommand "deadnix-check" {
          buildInputs = [ pkgs.deadnix ];
          src = pkgs.lib.cleanSource ../.;
        } ''
          echo "Running deadnix..."
          deadnix --fail "$src"
          touch $out
        '';

        # Manpage lint (helpful to keep docs tidy)
        # Include referenced manpages in MANPATH so cross-references resolve,
        # and do not suppress mandoc output to ease debugging in CI logs.
        man-lint = pkgs.runCommand "man-lint" {
          # Keep mandoc minimal, but add common refs used in dwl.1 so Xr checks pass.
          buildInputs = [
            pkgs.mandoc
            pkgs.foot
            pkgs.wmenu
            pkgs.dwm
            pkgs.xkeyboard_config
          ];
          src = pkgs.lib.cleanSource ../.;
        } ''
          set -euo pipefail
          echo "Linting manpage with mandoc..."
          # Work on a local copy to avoid odd path parsing in mandoc
          cp "$src/dwl.1" ./dwl.1
          # Ensure cross-references can be resolved by mandoc
          export MANPATH="${pkgs.foot}/share/man:${pkgs.wmenu}/share/man:${pkgs.dwm}/share/man:${pkgs.xkeyboard_config}/share/man"
          mandoc -Tlint -Werror ./dwl.1
          touch $out
        '';
      };
    };
}
