{
  terminal = {
    argv = [ "ghostty" ];
    # Wayland app_id/class for the terminal, used to mark swallowing parents. If 
    # omitted, the first argv element is used.
    appId = "ghostty";
  };

  menu = {
    argv = [ "bemenu-run" ];
  };

  # Base client rules. isterm can be injected automatically for swallow
  # parents via swallowTerminals (see below), but we keep the explicit
  # ghostty rule to preserve the current behaviour.
  rules = [
    { id = "ghostty"; isterm = true; }
    { id = "zen"; tags = [ 0 ]; }
    { id = "vesktop"; tags = [ 2 ]; }
    { id = "mpv"; tags = [ 3 ]; }
    { id = "ghostty.capture"; isfloating = true; }
    { id = "ghostty.journal"; isfloating = true; }
  ];

  # Which app_id(s) should be treated as terminals for autoswallow.
  # When set, config-h.nix will:
  #   - force .isterm = true on matching rules
  #   - add a minimal Rule if no rule exists for a listed id
  # If omitted, it defaults to [ terminal.appId or head terminal.argv ].
  swallowTerminals = [ "ghostty" ];

  scratchpads = [
    {
      name = "termscratch";
      key = "t";
      keysym = "XKB_KEY_t";
      id = "ghostty.term";
      isterm = true;
      argv = [ "ghostty" "--class=ghostty.term" "--title=Terminal" ];
    }
    {
      name = "btopscratch";
      key = "b";
      keysym = "XKB_KEY_b";
      id = "ghostty.btop";
      isterm = true;
      argv = [ "ghostty" "--class=ghostty.btop" "--title=Btop" "-e" "btop" ];
    }
    {
      name = "musicscratch";
      key = "m";
      keysym = "XKB_KEY_m";
      id = "ghostty.music";
      isterm = true;
      argv = [
        "ghostty"
        "--class=ghostty.music"
        "--title=Music"
        "-e"
        "spotify_player"
      ];
    }
    {
      name = "notescratch";
      key = "n";
      keysym = "XKB_KEY_n";
      id = "ghostty.note";
      isterm = true;
      argv = [
        "ghostty"
        "--class=ghostty.note"
        "--title=Notes"
        "-e"
        "tmux"
        "new-session"
        "-As"
        "Notes"
        "-c"
        "/home/demiurge/Documents/Notes/Contents"
        "direnv"
        "exec"
        "."
        "nvim"
      ];
    }
    {
      name = "ircscratch";
      key = "i";
      keysym = "XKB_KEY_i";
      id = "ghostty.irc";
      isterm = true;
      argv = [
        "ghostty"
        "--class=ghostty.irc"
        "--title=IRC"
        "-e"
        "tmux"
        "new-session"
        "-As"
        "IRC"
        "irssi"
      ];
    }
    {
      name = "taskscratch";
      key = "d";
      keysym = "XKB_KEY_d";
      id = "ghostty.task";
      isterm = true;
      argv = [ "ghostty" "--class=ghostty.task" "--title=Task" "-e" "taskwarrior-tui" ];
    }
    {
      name = "signalscratch";
      key = "s";
      keysym = "XKB_KEY_s";
      id = "signal";
      argv = [ "signal-desktop" ];
    }
  ];

  # Order to emit scratchpad keybindings (names from scratchpads list)
  scratchKeyOrder = [
    "termscratch"
    "notescratch"
    "signalscratch"
    "btopscratch"
    "musicscratch"
    "ircscratch"
    "taskscratch"
  ];

  # Order to emit scratchpad rules
  scratchRuleOrder = [
    "termscratch"
    "notescratch"
    "btopscratch"
    "musicscratch"
    "ircscratch"
    "taskscratch"
    "signalscratch"
  ];

  # Extra keybinds appended to keys[] (same shape as derivation's legacy
  # extraKeybinds argument).
  extraKeybinds = [ ];
}
