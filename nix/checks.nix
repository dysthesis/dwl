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
        fcft
      ];

      xDeps = with pkgs.xorg; [
        libxcb
        xcbutilwm
      ];

      # cppcheck static analysis
      mkCppcheck =
        {
          enableXWayland ? false,
        }:
        pkgs.stdenv.mkDerivation {
          pname = "dwl-cppcheck";
          version = "1";
          src = pkgs.lib.cleanSource ../.;
          nativeBuildInputs = with pkgs; [
            pkg-config
            wayland-scanner
            gnumake
            cppcheck
            coreutils
            findutils
          ];
          buildInputs = commonBuildInputs ++ pkgs.lib.optionals enableXWayland xDeps;
          dontConfigure = true;
          buildPhase = ''
            set -euo pipefail
            echo "Generating Wayland protocol headers for analysis..."
            make \
              WAYLAND_SCANNER=${pkgs.wayland-scanner.bin}/bin/wayland-scanner \
              cursor-shape-v1-protocol.h \
              pointer-constraints-unstable-v1-protocol.h \
              wlr-layer-shell-unstable-v1-protocol.h \
              wlr-output-power-management-unstable-v1-protocol.h \
              xdg-shell-protocol.h

            echo "Collecting include/define flags..."
            PKGS="wayland-server xkbcommon libinput pixman-1 fcft${pkgs.lib.optionalString enableXWayland " xcb xcb-icccm"}"
            # Prefer wlroots-0.19 but fall back to wlroots if needed
            if ${pkgs.pkg-config}/bin/pkg-config --exists wlroots-0.19; then
              WLR_INCS=$(${pkgs.pkg-config}/bin/pkg-config --cflags wlroots-0.19)
            else
              WLR_INCS=$(${pkgs.pkg-config}/bin/pkg-config --cflags wlroots)
            fi
            CFLAGS_RAW=$(${pkgs.pkg-config}/bin/pkg-config --cflags $PKGS)
            # Filter only -I and -D flags for cppcheck
            FILTERED=""
            for t in $CFLAGS_RAW $WLR_INCS; do
              case "$t" in
                -I*|-D*) FILTERED="$FILTERED $t" ;;
              esac
            done

            echo "Running cppcheck..."
            # Analyze all C files in the tree root (dwl.c, util.c)
            sources=$(ls *.c)
            ${pkgs.cppcheck}/bin/cppcheck \
              --std=c11 \
              --language=c \
              --force \
              --inline-suppr \
              --enable=warning,performance,portability \
              --check-level=exhaustive \
              --error-exitcode=1 \
              -I . $FILTERED \
              $sources
          '';
          installPhase = ''
            mkdir -p "$out"
            touch "$out/ok"
          '';
        };

      # clang-tidy static analysis (clang-analyzer checks)
      mkClangTidy =
        {
          enableXWayland ? false,
        }:
        pkgs.stdenv.mkDerivation {
          pname = "dwl-clang-tidy";
          version = "1";
          src = pkgs.lib.cleanSource ../.;
          nativeBuildInputs = with pkgs; [
            pkg-config
            wayland-scanner
            gnumake
            clang
            clang-tools
            coreutils
            findutils
          ];
          buildInputs = commonBuildInputs ++ pkgs.lib.optionals enableXWayland xDeps;
          dontConfigure = true;
          buildPhase = ''
            set -euo pipefail
            echo "Generating Wayland protocol headers for analysis..."
            make \
              WAYLAND_SCANNER=${pkgs.wayland-scanner.bin}/bin/wayland-scanner \
              cursor-shape-v1-protocol.h \
              pointer-constraints-unstable-v1-protocol.h \
              wlr-layer-shell-unstable-v1-protocol.h \
              wlr-output-power-management-unstable-v1-protocol.h \
              xdg-shell-protocol.h

            echo "Collecting include/define flags..."
            PKGS="wayland-server xkbcommon libinput pixman-1 fcft${pkgs.lib.optionalString enableXWayland " xcb xcb-icccm"}"
            if ${pkgs.pkg-config}/bin/pkg-config --exists wlroots-0.19; then
              WLR_INCS=$(${pkgs.pkg-config}/bin/pkg-config --cflags wlroots-0.19)
            else
              WLR_INCS=$(${pkgs.pkg-config}/bin/pkg-config --cflags wlroots)
            fi
            CFLAGS_RAW=$(${pkgs.pkg-config}/bin/pkg-config --cflags $PKGS)
            FILTERED=""
            for t in $CFLAGS_RAW $WLR_INCS; do
              case "$t" in
                -I*|-D*) FILTERED="$FILTERED $t" ;;
              esac
            done

            echo "Running clang-tidy (clang-analyzer checks only)..."
            sources=$(ls *.c)
            fail=0
            for f in $sources; do
              echo "  -> $f"
              ${pkgs.clang-tools}/bin/clang-tidy \
                -quiet \
                -checks=clang-analyzer-* \
                "$f" -- \
                -std=c11 \
                -DWLR_USE_UNSTABLE \
                -D_POSIX_C_SOURCE=200809L \
                -DVERSION=\"0.0\" \
                -I . $FILTERED \
              || fail=1
            done
            test $fail -eq 0
          '';
          installPhase = ''
            mkdir -p "$out"
            touch "$out/ok"
          '';
        };

      mkScanBuild =
        {
          enableXWayland ? false,
        }:
        pkgs.stdenv.mkDerivation {
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
            # Use the Nix-patched scan-build wrapper from clang-analyzer to avoid /usr/bin/env shebangs
            ${pkgs.clang-analyzer}/bin/scan-build \
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

      # Strict Clang build (XWayland)
      clangWerrorX = pkgs.callPackage ./pkgs/dwl.nix {
        stdenv = pkgs.clangStdenv;
        enableXWayland = true;
        inherit (pkgs) xorg;
      };

      # Strict GCC build with -fanalyzer
      gccFanalyzer = pkgs.callPackage ./pkgs/dwl.nix {
        stdenv = pkgs.gccStdenv;
      };

      # Strict GCC build with -fanalyzer (XWayland)
      gccFanalyzerX = pkgs.callPackage ./pkgs/dwl.nix {
        stdenv = pkgs.gccStdenv;
        enableXWayland = true;
        inherit (pkgs) xorg;
      };
    in
    {
      checks = {
        # Build the default package (ensures normal build stays green)
        build = config.packages.dwl;

        # Build with XWayland support toggled on
        build-xwayland = pkgs.callPackage ./pkgs/dwl.nix {
          enableXWayland = true;
          inherit (pkgs) xorg;
        };

        # Clang analyzer via scan-build as a dedicated check (HTML report in result/scan-report)
        scan-build = mkScanBuild { enableXWayland = false; };
        scan-build-xwayland = mkScanBuild { enableXWayland = true; };

        # cppcheck static analysis (C11)
        cppcheck = mkCppcheck { enableXWayland = false; };
        cppcheck-xwayland = mkCppcheck { enableXWayland = true; };

        # clang-tidy static analysis (clang-analyzer checks)
        clang-tidy = mkClangTidy { enableXWayland = false; };
        clang-tidy-xwayland = mkClangTidy { enableXWayland = true; };

        clang-werror = clangWerror.overrideAttrs (prev: {
          NIX_CFLAGS_COMPILE =
            (prev.NIX_CFLAGS_COMPILE or "") + " -Werror -Wformat -Wformat-security -Wundef";
        });
        clang-werror-xwayland = clangWerrorX.overrideAttrs (prev: {
          NIX_CFLAGS_COMPILE =
            (prev.NIX_CFLAGS_COMPILE or "") + " -Werror -Wformat -Wformat-security -Wundef";
        });

        gcc-fanalyzer = gccFanalyzer.overrideAttrs (prev: {
          NIX_CFLAGS_COMPILE =
            (prev.NIX_CFLAGS_COMPILE or "") + " -fanalyzer -Werror -Wformat -Wformat-security";
        });
        gcc-fanalyzer-xwayland = gccFanalyzerX.overrideAttrs (prev: {
          NIX_CFLAGS_COMPILE =
            (prev.NIX_CFLAGS_COMPILE or "") + " -fanalyzer -Werror -Wformat -Wformat-security";
        });

        # Nix code hygiene
        nixfmt =
          pkgs.runCommand "nixfmt-check"
            {
              buildInputs = [
                pkgs.nixfmt
                pkgs.findutils
              ];
              src = pkgs.lib.cleanSource ../.;
            }
            ''
              echo "Checking Nix formatting with nixfmt..."
              files=$(find "$src" -type f -name '*.nix')
              if [ -n "$files" ]; then
                nixfmt --check $files
              fi
              touch $out
            '';

        statix =
          pkgs.runCommand "statix-check"
            {
              buildInputs = [ pkgs.statix ];
              src = pkgs.lib.cleanSource ../.;
            }
            ''
              echo "Running statix..."
              statix check "$src"
              touch $out
            '';

        deadnix =
          pkgs.runCommand "deadnix-check"
            {
              buildInputs = [ pkgs.deadnix ];
              src = pkgs.lib.cleanSource ../.;
            }
            ''
              echo "Running deadnix..."
              deadnix --fail "$src"
              touch $out
            '';

        # Manpage lint (helpful to keep docs tidy)
        # Include referenced manpages in MANPATH so cross-references resolve,
        # and do not suppress mandoc output to ease debugging in CI logs.
        man-lint =
          pkgs.runCommand "man-lint"
            {
              # Keep mandoc minimal, but add common refs used in dwl.1 so Xr checks pass.
              buildInputs = [
                pkgs.mandoc
                pkgs.foot
                pkgs.wmenu
                pkgs.dwm
                pkgs.xkeyboard_config
              ];
              src = pkgs.lib.cleanSource ../.;
            }
            ''
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
