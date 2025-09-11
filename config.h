/* Taken from https://github.com/djpohly/dwl/issues/466 */
#define COLOR(hex)                                                             \
  {((hex >> 24) & 0xFF) / 255.0f, ((hex >> 16) & 0xFF) / 255.0f,               \
   ((hex >> 8) & 0xFF) / 255.0f, (hex & 0xFF) / 255.0f}
/* appearance */
static const int sloppyfocus = 1; /* focus follows mouse */
static const int bypass_surface_visibility =
    0; /* 1 means idle inhibitors will disable idle tracking even if it's
          surface isn't visible  */
static const int smartborders = 1;
static const unsigned int borderpx = 1; /* border pixel of windows */
static const float rootcolor[] = COLOR(0x000000ff);
static const float bordercolor[] = COLOR(0x040404ff);
static const float focuscolor[] = COLOR(0xffffffff);
static const float urgentcolor[] = COLOR(0xffaa88ff);
static const char *cursor_theme = "Bibata-Modern-Classic";
static const char cursor_size[] =
    "18"; /* Make sure it's a valid integer, otherwise things will break */
/* This conforms to the xdg-protocol. Set the alpha to zero to restore the old
 * behavior */
static const float fullscreen_bg[] = {0.0f, 0.0f, 0.0f,
                                      1.0f}; /* You can also use glsl colors */
static int enableautoswallow =
    1; /* enables autoswallowing newly spawned clients */
static float swallowborder = 1.0f; /* add this multiplied by borderpx to border
                                      when a client is swallowed */
static const int respect_monitor_reserved_area =
    0; /* 1 to monitor center while respecting the monitor's reserved area, 0 to
          monitor center */

/* tagging - TAGCOUNT must be no greater than 31 */
#define TAGCOUNT (9)

/* logging */
static int log_level = WLR_ERROR;

/* Autostart */
static const char *const autostart[] = {
    "wbg", "/path/to/your/image", NULL, NULL /* terminate */
};

/* NOTE: ALWAYS keep a rule declared even if you don't use rules (e.g leave at
 * least one example) */

#define RULE(...) {.monitor = -1, __VA_ARGS__}
#define SCRATCH(...) RULE(.isfloating = 1, .w = 0.75, .h = 0.75, __VA_ARGS__)
static const Rule rules[] = {
    RULE(.id = "ghostty", .isterm = 1),
    RULE(.id = "zen", .tags = 1 << 0),
    RULE(.id = "vesktop", .tags = 1 << 2),
    RULE(.id = "mpv", .tags = 1 << 3),

    SCRATCH(.id = "ghostty.term", .isterm = 1, .scratchkey = 't'),
    SCRATCH(.id = "ghostty.note", .isterm = 1, .scratchkey = 'n'),
    SCRATCH(.id = "ghostty.btop", .isterm = 1, .scratchkey = 'b'),
    SCRATCH(.id = "ghostty.music", .isterm = 1, .scratchkey = 'm'),
    SCRATCH(.id = "ghostty.irc", .isterm = 1, .scratchkey = 'i'),
    SCRATCH(.id = "ghostty.task", .isterm = 1, .scratchkey = 'd'),
    SCRATCH(.id = "signal", .scratchkey = 's'),
};

/* layout(s) */
static const Layout layouts[] = {
    /* symbol     arrange function */
    {"  ", tile},
    {"  ", NULL}, /* no layout function means floating behavior */
    {"   ", monocle},
};

/* monitors */
/* (x=-1, y=-1) is reserved as an "autoconfigure" monitor position indicator
 * WARNING: negative values other than (-1, -1) cause problems with Xwayland
 * clients https://gitlab.freedesktop.org/xorg/xserver/-/issues/899
 */
/* NOTE: ALWAYS add a fallback rule, even if you are completely sure it won't be
 * used */
static const MonitorRule monrules[] = {
    /* name   scale  rotate/reflect                x    y */
    /* example of a HiDPI laptop monitor:
    { "eDP-1",    2, WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
    */
    /* defaults */
    {NULL, 1, WL_OUTPUT_TRANSFORM_NORMAL, -1, -1},
};

static const TagRule tagrules[] = {
    /* tag     mfact      nmaster   layout */
    /* defaults */
    {0, 0.55f, 1, &layouts[0]}};

/* keyboard */
static const struct xkb_rule_names xkb_rules = {
    /* can specify fields: rules, model, layout, variant, options */
    /* example:
    .options = "ctrl:nocaps",
    */
    .options = NULL,
};

static const int repeat_rate = 25;
static const int repeat_delay = 600;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 1;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
/* You can choose between:
LIBINPUT_CONFIG_SCROLL_NO_SCROLL
LIBINPUT_CONFIG_SCROLL_2FG
LIBINPUT_CONFIG_SCROLL_EDGE
LIBINPUT_CONFIG_SCROLL_ON_BUTTON_DOWN
*/
static const enum libinput_config_scroll_method scroll_method =
    LIBINPUT_CONFIG_SCROLL_2FG;

/* You can choose between:
LIBINPUT_CONFIG_CLICK_METHOD_NONE
LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS
LIBINPUT_CONFIG_CLICK_METHOD_CLICKFINGER
*/
static const enum libinput_config_click_method click_method =
    LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;

/* You can choose between:
LIBINPUT_CONFIG_SEND_EVENTS_ENABLED
LIBINPUT_CONFIG_SEND_EVENTS_DISABLED
LIBINPUT_CONFIG_SEND_EVENTS_DISABLED_ON_EXTERNAL_MOUSE
*/
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;

/* You can choose between:
LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT
LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE
*/
static const enum libinput_config_accel_profile accel_profile =
    LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;

/* You can choose between:
LIBINPUT_CONFIG_TAP_MAP_LRM -- 1/2/3 finger tap maps to left/right/middle
LIBINPUT_CONFIG_TAP_MAP_LMR -- 1/2/3 finger tap maps to left/middle/right
*/
static const enum libinput_config_tap_button_map button_map =
    LIBINPUT_CONFIG_TAP_MAP_LRM;

/* If you want to use the windows key for MODKEY, use WLR_MODIFIER_LOGO */
#define MODKEY WLR_MODIFIER_LOGO

#define TAGKEYS(KEY, SKEY, TAG)                                                \
  {MODKEY, KEY, view, {.ui = 1 << TAG}},                                       \
      {MODKEY | WLR_MODIFIER_CTRL, KEY, toggleview, {.ui = 1 << TAG}},         \
      {MODKEY | WLR_MODIFIER_SHIFT, SKEY, tag, {.ui = 1 << TAG}}, {            \
    MODKEY | WLR_MODIFIER_CTRL | WLR_MODIFIER_SHIFT, SKEY, toggletag, {        \
      .ui = 1 << TAG                                                           \
    }                                                                          \
  }

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd)                                                             \
  {                                                                            \
    .v = (const char *[]) { "/bin/sh", "-c", cmd, NULL }                       \
  }

/* commands */
static const char *termcmd[] = {"ghostty", NULL};
static const char *menucmd[] = {"bemenu-run", NULL};

/* named scratchpads - First arg only serves to match against key in rules*/
// static const char *scratchpadcmd[] = { "s", "alacritty", "-t", "scratchpad",
// NULL };

static const char *termscratch[] = {"t", "ghostty", "--class=ghostty.term",
                                    "--title=Terminal", NULL};
static const char *btopscratch[] = {
    "b", "ghostty", "--class=ghostty.btop", "--title=Btop", "-e", "btop", NULL};
static const char *musicscratch[] = {"m",
                                     "ghostty",
                                     "--class=ghostty.music",
                                     "--title=Music",
                                     "-e",
                                     "spotify_player",
                                     NULL};
static const char *notescratch[] = {
    "n",
    "ghostty",
    "--class=ghostty.note",
    "--title=Notes",
    "-e",
    "tmux new-session -As Notes -c ~/Documents/Notes/Contents 'direnv exec . "
    "nvim'",
    NULL};
static const char *ircscratch[] = {
    "i",           "ghostty", "--class=ghostty.irc",
    "--title=IRC", "-e",      "tmux new-session -As IRC irssi",
    NULL};
static const char *taskscratch[] = {"d",
                                    "ghostty",
                                    "--class=ghostty.task",
                                    "--title=Task",
                                    "-e",
                                    "taskwarrior-tui",
                                    NULL};
static const char *signalscratch[] = {"s", "signal-desktop", NULL};

const char *raisevol[] = {
    "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+", NULL,
};
const char *lowervol[] = {"wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-",
                          NULL};
const char *raisebright[] = {"brightnessctl", "set", "5%+", NULL};
const char *lowerbright[] = {"brightnessctl", "set", "5%-", NULL};

static const Key keys[] = {
    /* Note that Shift changes certain key codes: c -> C, 2 -> at, etc. */
    /* modifier                  key                 function        argument */
    {MODKEY, XKB_KEY_r, spawn, {.v = menucmd}},
    {MODKEY, XKB_KEY_Return, spawn, {.v = termcmd}},
    {0, XKB_KEY_XF86AudioRaiseVolume, spawn, {.v = raisevol}},
    {0, XKB_KEY_XF86AudioLowerVolume, spawn, {.v = lowervol}},
    {0, XKB_KEY_XF86MonBrightnessUp, spawn, {.v = raisebright}},
    {0, XKB_KEY_XF86MonBrightnessDown, spawn, {.v = lowerbright}},
    {MODKEY, XKB_KEY_t, focusortogglematchingscratch, {.v = termscratch}},
    {MODKEY, XKB_KEY_n, focusortogglematchingscratch, {.v = notescratch}},
    {MODKEY, XKB_KEY_s, focusortogglematchingscratch, {.v = signalscratch}},
    {MODKEY, XKB_KEY_b, focusortogglematchingscratch, {.v = btopscratch}},
    {MODKEY, XKB_KEY_m, focusortogglematchingscratch, {.v = musicscratch}},
    {MODKEY, XKB_KEY_i, focusortogglematchingscratch, {.v = ircscratch}},
    {MODKEY, XKB_KEY_d, focusortogglematchingscratch, {.v = taskscratch}},
    {MODKEY, XKB_KEY_j, focusstack, {.i = +1}},
    {MODKEY, XKB_KEY_k, focusstack, {.i = -1}},
    {MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_J, movestack, {.i = +1}},
    {MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_K, movestack, {.i = -1}},
    {MODKEY, XKB_KEY_i, incnmaster, {.i = +1}},
    {MODKEY, XKB_KEY_d, incnmaster, {.i = -1}},
    {MODKEY, XKB_KEY_h, setmfact, {.f = -0.05f}},
    {MODKEY, XKB_KEY_l, setmfact, {.f = +0.05f}},
    {MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_Return, zoom, {0}},
    {MODKEY, XKB_KEY_Tab, view, {0}},
    {MODKEY, XKB_KEY_q, killclient, {0}},
    {MODKEY, XKB_KEY_t, setlayout, {.v = &layouts[0]}},
    {MODKEY, XKB_KEY_f, setlayout, {.v = &layouts[1]}},
    {MODKEY, XKB_KEY_m, setlayout, {.v = &layouts[2]}},
    {MODKEY, XKB_KEY_space, setlayout, {0}},
    {MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_space, togglefloating, {0}},
    {MODKEY, XKB_KEY_e, togglefullscreen, {0}},
    {MODKEY, XKB_KEY_a, toggleswallow, {0}},
    {MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_A, toggleautoswallow, {0}},
    {MODKEY, XKB_KEY_0, view, {.ui = ~0}},
    {MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_parenright, tag, {.ui = ~0}},
    {MODKEY, XKB_KEY_comma, focusmon, {.i = WLR_DIRECTION_LEFT}},
    {MODKEY, XKB_KEY_period, focusmon, {.i = WLR_DIRECTION_RIGHT}},
    {MODKEY | WLR_MODIFIER_SHIFT,
     XKB_KEY_less,
     tagmon,
     {.i = WLR_DIRECTION_LEFT}},
    {MODKEY | WLR_MODIFIER_SHIFT,
     XKB_KEY_greater,
     tagmon,
     {.i = WLR_DIRECTION_RIGHT}},
    TAGKEYS(XKB_KEY_1, XKB_KEY_exclam, 0),
    TAGKEYS(XKB_KEY_2, XKB_KEY_at, 1),
    TAGKEYS(XKB_KEY_3, XKB_KEY_numbersign, 2),
    TAGKEYS(XKB_KEY_4, XKB_KEY_dollar, 3),
    TAGKEYS(XKB_KEY_5, XKB_KEY_percent, 4),
    TAGKEYS(XKB_KEY_6, XKB_KEY_asciicircum, 5),
    TAGKEYS(XKB_KEY_7, XKB_KEY_ampersand, 6),
    TAGKEYS(XKB_KEY_8, XKB_KEY_asterisk, 7),
    TAGKEYS(XKB_KEY_9, XKB_KEY_parenleft, 8),
    {MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_Q, quit, {0}},

    /* Ctrl-Alt-Backspace and Ctrl-Alt-Fx used to be handled by X server */
    {WLR_MODIFIER_CTRL | WLR_MODIFIER_ALT, XKB_KEY_Terminate_Server, quit, {0}},
/* Ctrl-Alt-Fx is used to switch to another VT, if you don't know what a VT is
 * do not remove them.
 */
#define CHVT(n)                                                                \
  {                                                                            \
    WLR_MODIFIER_CTRL | WLR_MODIFIER_ALT, XKB_KEY_XF86Switch_VT_##n, chvt, {   \
      .ui = (n)                                                                \
    }                                                                          \
  }
    CHVT(1),
    CHVT(2),
    CHVT(3),
    CHVT(4),
    CHVT(5),
    CHVT(6),
    CHVT(7),
    CHVT(8),
    CHVT(9),
    CHVT(10),
    CHVT(11),
    CHVT(12),
};

static const Button buttons[] = {
    {MODKEY, BTN_LEFT, moveresize, {.ui = CurMove}},
    {MODKEY, BTN_MIDDLE, togglefloating, {0}},
    {MODKEY, BTN_RIGHT, moveresize, {.ui = CurResize}},
};
