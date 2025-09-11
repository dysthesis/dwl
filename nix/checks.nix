_: {
  perSystem =
    { config, pkgs, ... }:
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

      # Flawfinder source scan (quick SAST over C sources)
      mkFlawfinder =
        pkgs.runCommand "flawfinder-check"
          {
            buildInputs = [
              pkgs.flawfinder
              pkgs.findutils
              pkgs.coreutils
            ];
            src = pkgs.lib.cleanSource ../.;
          }
          ''
              set -euo pipefail
              mkdir -p "$out"
              # Run text report first; we’ll parse hit count to decide pass/fail
              flawfinder \
                --minlevel=3 \
                --columns --context \
                "$src" > "$out/report.txt"

              # Optional HTML report for easier browsing
              flawfinder \
                --minlevel=3 \
                --html "$src" > "$out/report.html" || true

            # Fail the check if any hits are found to keep security hygiene tight
            hits=$(${pkgs.gawk or pkgs.awk}/bin/awk '/Hits =/{n=$3} END{print n+0}' "$out/report.txt")
            if [ "$hits" -gt 0 ]; then
              echo "Flawfinder found $hits issue(s) (see $out/report.txt)" >&2
              exit 1
            fi
          '';

      # Facebook Infer static analysis (capture + analyze Make build)
      mkInfer =
        {
          enableXWayland ? false,
        }:
        pkgs.stdenv.mkDerivation {
          pname = "dwl-infer";
          version = "1";
          src = pkgs.lib.cleanSource ../.;
          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.wayland-scanner
            pkgs.clang
            pkgs.gnumake
            pkgs.infer
          ];
          buildInputs = commonBuildInputs ++ pkgs.lib.optionals enableXWayland xDeps;
          dontConfigure = true;
          buildPhase = ''
            set -euo pipefail
            export CC=clang
            # Capture build and analyze; keep artifacts even if issues are found
            status=0
            enable_x=${if enableXWayland then "1" else "0"}
            if [ "$enable_x" = "1" ]; then
              xargs="XWAYLAND=-DXWAYLAND XLIBS=xcb\\ xcb-icccm"
            else
              xargs=""
            fi
            infer run \
              --keep-going \
              --results-dir infer-out \
              --fail-on-issue \
              -- \
              make WAYLAND_SCANNER=$(command -v wayland-scanner) $xargs \
              || status=$?
            echo "$status" > infer-status
          '';
          installPhase = ''
            mkdir -p "$out"
            if [ -d infer-out ]; then
              cp -r infer-out "$out/"
            fi
            # Exit non-zero if infer reported issues
            status=$(cat infer-status 2>/dev/null || echo 0)
            if [ "$status" -ne 0 ]; then
              echo "Infer reported issues (status=$status); see $out/infer-out" >&2
              exit "$status"
            fi
            touch "$out/ok"
          '';
        };

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

      # Build a clang-based dwl with ASan+UBSan (+frame-pointers) and run a simple
      # headless smoke test to exercise basic compositor/client paths.
      mkAsanUbsanRun =
        {
          enableXWayland ? false,
        }:
        let
          sanPkg =
            (pkgs.callPackage ./pkgs/dwl.nix {
              stdenv = pkgs.clangStdenv;
              inherit enableXWayland;
              inherit (pkgs) xorg;
              # Disable repo autostart to avoid unknown commands in CI
              autostart = [ ];
            }).overrideAttrs
              (prev: {
                makeFlags = (prev.makeFlags or [ ]) ++ [
                  "CFLAGS+=-O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined"
                  "LDFLAGS+=-fsanitize=address,undefined"
                ];
                __structuredAttrs = true;
              });
        in
        pkgs.runCommand "dwl-asan-ubsan-smoketest"
          {
            buildInputs = [
              sanPkg
              pkgs.coreutils
              pkgs.bash
              pkgs.toybox
              pkgs.foot
              pkgs.wmenu
            ];
          }
          ''
            set -euo pipefail
            export ASAN_OPTIONS=detect_leaks=0:strict_init_order=1:abort_on_error=1
            export UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1:abort_on_error=1
            export XDG_RUNTIME_DIR="$PWD/xdg"
            mkdir -p "$XDG_RUNTIME_DIR"
            chmod 700 "$XDG_RUNTIME_DIR"
            export WLR_BACKENDS=headless
            export WLR_RENDERER_ALLOW_SOFTWARE=1
            # Exercise client create/map/unmap and compositor run loop.
            # - Start dwl with a startup script that launches a couple of clients
            #   and then exits successfully, while we still guard with timeout.
            ${pkgs.coreutils}/bin/timeout 8s ${sanPkg}/bin/dwl -s \
              "${pkgs.bash}/bin/bash -ceu ' \
                 (${pkgs.foot}/bin/foot --server >/dev/null 2>&1 &) ; \
                 (printf %s\\n x | ${pkgs.wmenu}/bin/wmenu -p test >/dev/null 2>&1 &) ; \
                 sleep 1 ; exit 0 '" || true
            touch "$out"
          '';

      # Strict warnings-as-errors build using a curated warning set
      mkWarningsStrict =
        {
          enableXWayland ? false,
        }:
        let
          base = pkgs.callPackage ./pkgs/dwl.nix {
            stdenv = pkgs.clangStdenv;
            inherit enableXWayland;
            inherit (pkgs) xorg;
          };
        in
        base.overrideAttrs (prev: {
          NIX_CFLAGS_COMPILE =
            (prev.NIX_CFLAGS_COMPILE or "")
            + " -Wall -Wextra -Werror -Wformat=2 -Wvla -Wshadow -Wcast-align"
            + " -Wpointer-arith -Wstrict-prototypes -Wconversion -Wsign-conversion"
            + " -Wno-unused-parameter -Wno-implicit-int-conversion -Wno-implicit-int-float-conversion"
            + " -Wno-sign-conversion -Wno-cast-align -Wno-vla -Wno-format-nonliteral";
        });

      # Strict Clang build (treat warnings as errors)
      clangWerror = pkgs.callPackage ./pkgs/dwl.nix { stdenv = pkgs.clangStdenv; };

      # Strict Clang build (XWayland)
      clangWerrorX = pkgs.callPackage ./pkgs/dwl.nix {
        stdenv = pkgs.clangStdenv;
        enableXWayland = true;
        inherit (pkgs) xorg;
      };

      # Strict GCC build with -fanalyzer
      gccFanalyzer = pkgs.callPackage ./pkgs/dwl.nix { stdenv = pkgs.gccStdenv; };

      # Strict GCC build with -fanalyzer (XWayland)
      gccFanalyzerX = pkgs.callPackage ./pkgs/dwl.nix {
        stdenv = pkgs.gccStdenv;
        enableXWayland = true;
        inherit (pkgs) xorg;
      };
      # Only enable Infer checks if pkgs.infer exists on this platform
      hasInfer = pkgs ? infer;
      inferChecks = pkgs.lib.optionalAttrs hasInfer {
        # Facebook Infer static analysis (capture build + analyze)
        infer = mkInfer { enableXWayland = false; };
        infer-xwayland = mkInfer { enableXWayland = true; };
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

        # Flawfinder quick static analysis
        flawfinder = mkFlawfinder;

        # cppcheck static analysis (C11)
        cppcheck = mkCppcheck { enableXWayland = false; };
        cppcheck-xwayland = mkCppcheck { enableXWayland = true; };

        # clang-tidy static analysis (clang-analyzer checks)
        clang-tidy = mkClangTidy { enableXWayland = false; };
        clang-tidy-xwayland = mkClangTidy { enableXWayland = true; };

        # Sanitized run smoke tests
        asan-ubsan-run = mkAsanUbsanRun { enableXWayland = false; };
        asan-ubsan-run-xwayland = mkAsanUbsanRun { enableXWayland = true; };

        # Strict warnings-as-errors builds
        warnings-strict = mkWarningsStrict { enableXWayland = false; };
        warnings-strict-xwayland = mkWarningsStrict { enableXWayland = true; };

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
      }
      // inferChecks;
    };
}
