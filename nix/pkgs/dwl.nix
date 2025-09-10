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
stdenv.mkDerivation {
  pname = "dwl";
  # Keep in sync with config.mk's _VERSION default; the runtime binary also embeds VERSION.
  version = "0.8-dev";

  src = srcDir;

  strictDeps = true;

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
  ];

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
