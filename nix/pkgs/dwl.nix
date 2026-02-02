{
  lib,
  stdenv,
  installShellFiles,
  makeWrapper,
  pkg-config,
  wayland,
  wayland-protocols,
  libinput,
  libxkbcommon,
  pixman,
  libdrm,
  libxcb,
  wayland-scanner,
  fcft,
  tllist,
  wlroots,
  wlroots_0_19 ? null,
  # X stack (autopassed by callPackage)
  xorg ? null,
  libX11 ? null,
  xwayland ? null,
  enableXWayland ? false,
  # Optional: inject autostart commands into config.h at build time.
  # Format: list of argv vectors, e.g. [ [ "wbg" "/path/img.png" ] [ "foot" "--server" ] ]
  autostart ? null,
  # Optional: append extra Key entries to config.h prior to build.
  # Format: list of attribute sets. Each entry may use either
  #   { modifiers = [ "MODKEY" "WLR_MODIFIER_SHIFT" ]; key = "XKB_KEY_F12";
  #     function = "spawn"; argument = { union = "v"; value = "menucmd"; };
  #     comment = "launch menu"; }
  # or
  #   { mod = "MODKEY"; key = "XKB_KEY_F12"; func = "spawn"; arg = "SHCMD(\"swaylock\")"; }
  # Fields:
  #   - modifiers (list of strings) or mod (string) supply the modifier mask.
  #   - key (string, required) is used verbatim.
  #   - function / func (string, required) names the handler.
  #   - argument / arg may be a string, a list of argv strings, a { raw = "..."; }
  #     block for verbatim C, or a { union = "v"; value = "cmd"; } form to emit
  #     {.v = cmd }.
  #   - comment (string, optional) appends a /* comment */ suffix to the line.
  extraKeybinds ? [ ],
  # Optional: packages to prepend to dwl's PATH at runtime.
  extraPathPackages ? [ ],
  # Avoid collision with pkgs.src when using callPackage
  srcDir ? ../..,
}:

let
  # Render a C string literal from a Nix string
  escapeCStr = s: lib.replaceStrings [ "\\" "\"" "\n" "\t" ] [ "\\\\" "\\\"" "\\n" "\\t" ] s;
  quoteC = s: "\"${escapeCStr s}\"";
  renderCmd = cmd: "  " + (lib.concatStringsSep ", " (map quoteC cmd)) + ", NULL,";
  renderAutostart =
    cmds:
    let
      lines = map renderCmd cmds;
      body = lib.concatStringsSep "\n" lines;
      nl = lib.optionalString (cmds != [ ]) "\n";
    in
    ''
      static const char *const autostart[] = {
      ${body}${nl}  NULL /* terminate */
      };'';

  escapeComment = c: lib.replaceStrings [ "*/" ] [ "* /" ] c;
  renderArgArray = union: argv:
    let
      quoted = map quoteC argv;
      joined = lib.concatStringsSep ", " quoted;
    in
    "{." + union + " = (const char *const[]){ " + joined + ", NULL }}";
  renderModifiers =
    kb:
    if kb ? modifiers then
      (if kb.modifiers == [ ] then "0" else lib.concatStringsSep " | " kb.modifiers)
    else
      kb.mod or "0";
  renderFunc = kb: kb.function or (kb.func or (throw "dwl: extra keybind missing function"));
  renderArg =
    kb:
    let
      arg =
        if kb ? argument then kb.argument
        else if kb ? arg then kb.arg
        else null;
    in
    if arg == null then
      "{0}"
    else if lib.isString arg then
      arg
    else if lib.isList arg then
      renderArgArray "v" arg
    else if lib.isAttrs arg then
      arg.raw or (
        if arg ? argv then
          renderArgArray (arg.union or "v") arg.argv
        else if arg ? union && arg ? value then
          "{." + arg.union + " = " + arg.value + " }"
        else
          throw "dwl: extra keybind argument attribute set missing raw, argv, or union/value"
      )
    else
      throw "dwl: extra keybind argument must be string, list, or attribute set";
  renderKeybind =
    kb:
    let
      key = kb.key or (throw "dwl: extra keybind missing key");
      func = renderFunc kb;
      mod = renderModifiers kb;
      arg = renderArg kb;
      comment = if kb ? comment then " /* " + escapeComment kb.comment + " */" else "";
    in
    "\t{ " + mod + ", " + key + ", " + func + ", " + arg + " }," + comment;
  renderKeybindBlock =
    keybinds:
    if keybinds == [ ] then
      ""
    else
      let
        lines = map renderKeybind keybinds;
        body = lib.concatStringsSep "\n" lines;
      in
      "\n\t/* extra keybinds injected via Nix */\n" + body + "\n";

  xDeps =
    if enableXWayland then
      [
        xorg.libxcb
        xorg.xcbutilwm
        libX11
        xwayland
      ]
    else
      [ ];
  xMakeFlags =
    if enableXWayland then
      [
        # Whitespace requires structured attrs; quote like nixpkgs
        ''XWAYLAND="-DXWAYLAND"''
        ''XLIBS="xcb xcb-icccm"''
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
    installShellFiles
    makeWrapper
  ];

  buildInputs =
    let
      wlrootsPkg =
        if wlroots_0_19 != null then
          wlroots_0_19
        else if wlroots != null then
          wlroots
        else
          throw "dwl: no wlroots package found (expected wlroots_0_19 or wlroots)";
    in
    [
      libinput
      libxcb
      libxkbcommon
      pixman
      wayland
      wayland-protocols
      wlrootsPkg
      # bar patch
      fcft
      tllist
      libdrm
    ]
    ++ xDeps;

  # Ensure installation under $out and point scanner directly
  makeFlags = xMakeFlags ++ [
    "PKG_CONFIG=${stdenv.cc.targetPrefix}pkg-config"
    "WAYLAND_SCANNER=${wayland-scanner.bin}/bin/wayland-scanner"
  ];
  installFlags = [ "PREFIX=$(out)" ];

  # Required for makeFlags entries with spaces (XLIBS)
  __structuredAttrs = true;

  # Optionally inject autostart block into config.h prior to build/scan-build
  postPatch = lib.concatStrings [
    (lib.optionalString (autostart != null) (
      let
        block = renderAutostart autostart;
      in
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
    ))
    (lib.optionalString (extraKeybinds != [ ]) (
      let
        keyblock = renderKeybindBlock extraKeybinds;
      in
      # sh
      ''
              echo "Injecting extra keybinds into config.h"
              if [ ! -f config.h ]; then
                cp config.def.h config.h
              fi

              cat > keybinds.block << 'EOF'
        ${keyblock}
        EOF

              startline=$(grep -n -E '^static const Key keys\[\] = \{$' config.h | cut -d: -f1)
              if [ -z "$startline" ]; then
                echo "error: could not find keys[] in config.h" >&2
                exit 1
              fi
              endline=$(awk 'NR>'"$startline"' && /^[[:space:]]*};[[:space:]]*$/{ print NR; exit }' config.h)
              if [ -z "$endline" ]; then
                echo "error: could not determine end of keys[] block in config.h" >&2
                exit 1
              fi

              head -n "$((endline - 1))" config.h > config.h.new
              cat keybinds.block >> config.h.new
              tail -n "+$endline" config.h >> config.h.new
              mv config.h.new config.h
      ''
    ))
  ];

  postInstall = ''
    if [ -f config.h ]; then
      install -Dm0644 config.h "$out/share/dwl/config.h"
    else
      echo "warning: config.h not found during install" >&2
    fi
  '';

  postFixup = lib.optionalString (extraPathPackages != [ ]) ''
    wrapProgram $out/bin/dwl \
      --prefix PATH : ${lib.makeBinPath extraPathPackages}
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
