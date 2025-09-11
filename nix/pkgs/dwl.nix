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
  # Optional: inject autostart commands into config.h at build time.
  # Format: list of argv vectors, e.g. [ [ "wbg" "/path/img.png" ] [ "foot" "--server" ] ]
  autostart ? null,
  # Avoid collision with pkgs.src when using callPackage
  srcDir ? ../..,
}:

let
  # Render a C string literal from a Nix string
  escapeCStr = s: lib.replaceStrings [ "\\"  "\""  "\n"  "\t" ] [ "\\\\" "\\\"" "\\n" "\\t" ] s;
  quoteC = s: "\"${escapeCStr s}\"";
  renderCmd = cmd: "  " + (lib.concatStringsSep ", " (map quoteC cmd)) + ", NULL,";
  renderAutostart = cmds:
    let
      lines = map renderCmd cmds;
      body = lib.concatStringsSep "\n" lines;
      nl = lib.optionalString (cmds != [ ]) "\n";
    in ''static const char *const autostart[] = {
${body}${nl}  NULL /* terminate */
};'';

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

  # Optionally inject autostart block into config.h prior to build/scan-build
  postPatch = lib.optionalString (autostart != null) (
    let block = renderAutostart autostart; in
    # sh
    ''
      echo "Injecting autostart into config.h"
      # Ensure a config.h exists to patch
      if [ ! -f config.h ]; then
        cp config.def.h config.h
      fi

      cat > autostart.block << 'EOF'
${block}
EOF

      # Find range for the existing autostart[] block and replace it atomically
      startline=$(grep -n -E '^static const char \*const autostart\[\] = \{$' config.h | cut -d: -f1)
      if [ -z "$startline" ]; then
        echo "error: could not find autostart[] in config.h" >&2
        exit 1
      fi
      endline=$(awk 'NR>'"$startline"' && /^[[:space:]]*};[[:space:]]*$/ { print NR; exit }' config.h)
      if [ -z "$endline" ]; then
        echo "error: could not find end of autostart[] block in config.h" >&2
        exit 1
      fi

      head -n "$((startline - 1))" config.h > config.h.new
      cat autostart.block >> config.h.new
      tail -n "+$((endline + 1))" config.h >> config.h.new
      mv config.h.new config.h
    ''
  );

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
