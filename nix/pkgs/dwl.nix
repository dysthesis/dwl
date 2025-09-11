{
  lib,
  stdenv,
  pkg-config,
  wayland,
  wayland-protocols,
  libinput,
  libxkbcommon,
  pixman,
  libdrm,
  seatd,
  wayland-scanner,
  # Optional: static analyzer tooling
  clang-analyzer,
  clang ? null,
  wlroots_0_19 ? null,
  wlroots ? null,
  xorg ? null,
  enableXWayland ? false,
  # Avoid collision with pkgs.src when using callPackage
  srcDir ? ../..,
}:

let
  wlrootsPkg =
    if wlroots_0_19 != null then
      wlroots_0_19
    else if wlroots != null then
      wlroots
    else
      throw "dwl: no wlroots package found (expected wlroots_0_19 or wlroots)";

  xDeps =
    if enableXWayland && xorg != null then
      [
        xorg.libxcb
        xorg.xcbutilwm
      ]
    else
      [ ];
  xMakeFlags =
    if enableXWayland then
      [
        "XWAYLAND=-DXWAYLAND"
        "XLIBS=xcb xcb-icccm"
      ]
    else
      [ ];
in
stdenv.mkDerivation rec {
  pname = "dwl";
  # Keep in sync with config.mk's _VERSION default; the runtime binary also embeds VERSION.
  version = "0.8-dev";

  src = srcDir;

  strictDeps = true;

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
    clang-analyzer
  ]
  ++ lib.optionals (clang != null) [ clang ];

  buildInputs = [
    wayland # wayland-server
    wlrootsPkg
    libinput
    libxkbcommon
    pixman
    libdrm
    seatd
    wayland-protocols
  ]
  ++ xDeps;

  # Ensure installation under $out and point scanner directly
  makeFlags = xMakeFlags ++ [
    "WAYLAND_SCANNER=${wayland-scanner.bin}/bin/wayland-scanner"
  ];
  installFlags = [ "PREFIX=$(out)" ];

  # Run clang static analyzer prior to actual compilation. If available,
  # this will fail the build when bugs are detected (status-bugs).
  preBuild = # sh
    ''
      echo "Running clang-analyzer (scan-build) prior to compilation..."
      export CC="${if clang != null then "${clang}/bin/clang" else "cc"}"
      export CXX="${if clang != null then "${clang}/bin/clang++" else "c++"}"
      "${clang-analyzer}/bin/scan-build" \
        --status-bugs \
        --use-cc="$CC" \
        --use-c++="$CXX" \
        -o "$TMPDIR/scan-build" \
        make ${lib.concatStringsSep " " makeFlags}
    '';

  # No tests provided
  doCheck = false;

  meta = with lib; {
    description = "dwm for Wayland (wlroots-based)";
    homepage = "https://codeberg.org/dwl/dwl";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "dwl";
  };
}
