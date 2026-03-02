{ lib }:

let
  # Base template and spec shipped in the repo
  defaultTemplate = builtins.readFile ../config/config-template.h;
  defaultSpec = import ../config/spec.nix;

  boolInt = b: if b then "1" else "0";

  escapeCStr = s: lib.replaceStrings [ "\\" "\"" "\n" "\t" ] [ "\\\\" "\\\"" "\\n" "\\t" ] s;
  quoteC = s: "\"${escapeCStr s}\"";

  renderCmdArray =
    name: argv:
    let
      args = lib.concatStringsSep ", " (map quoteC argv ++ [ "NULL" ]);
    in
    "static const char *" + name + "[] = {" + args + "};";

  renderScratchCmd =
    sp:
    let
      args = [ sp.key ] ++ sp.argv;
      rendered = lib.concatStringsSep ", " (map quoteC args ++ [ "NULL" ]);
    in
    ''
static const char *${sp.name}[] = {
    ${rendered}};
''; # keep trailing newline to mirror config.h style

  renderTags =
    tags:
    if lib.isList tags then
      let
        bits = map (t: "1 << " + builtins.toString t) tags;
      in
      lib.concatStringsSep " | " bits
    else
      builtins.toString tags;

  renderRuleFields =
    r:
    let
      fields =
        [
          (".id = " + quoteC r.id)
        ]
        ++ lib.optional (r ? title) (".title = " + quoteC r.title)
        ++ lib.optional (r ? tags) (".tags = " + renderTags r.tags)
        ++ lib.optional (r ? isfloating) (".isfloating = " + boolInt r.isfloating)
        ++ lib.optional (r ? isterm) (".isterm = " + boolInt r.isterm)
        ++ lib.optional (r ? noswallow) (".noswallow = " + boolInt r.noswallow)
        ++ lib.optional (r ? monitor) (".monitor = " + builtins.toString r.monitor)
        ++ lib.optional (r ? scratchkey) (".scratchkey = '" + r.scratchkey + "'")
        ++ lib.optional (r ? x) (".x = " + builtins.toString r.x)
        ++ lib.optional (r ? y) (".y = " + builtins.toString r.y)
        ++ lib.optional (r ? w) (".w = " + builtins.toString r.w)
        ++ lib.optional (r ? h) (".h = " + builtins.toString r.h);
    in
    lib.concatStringsSep ", " fields;

  renderRule = r: "    RULE(" + renderRuleFields r + "),";

  renderScratchRule =
    sp:
    let
      fields =
        [
          (".id = " + quoteC sp.id)
        ]
        ++ lib.optional (sp ? isterm) (".isterm = " + boolInt sp.isterm)
        ++ lib.optional (sp ? noswallow) (".noswallow = " + boolInt sp.noswallow)
        ++ lib.optional (sp ? monitor) (".monitor = " + builtins.toString sp.monitor)
        ++ [
          (".scratchkey = '" + sp.key + "'")
        ]
        ++ lib.optional (sp ? x) (".x = " + builtins.toString sp.x)
        ++ lib.optional (sp ? y) (".y = " + builtins.toString sp.y)
        ++ lib.optional (sp ? w) (".w = " + builtins.toString sp.w)
        ++ lib.optional (sp ? h) (".h = " + builtins.toString sp.h);
    in
    "    SCRATCH(" + lib.concatStringsSep ", " fields + "),";

  renderScratchKeys =
    sp:
    let
      keysym = sp.keysym or ("XKB_KEY_" + sp.key);
    in
    "    {MODKEY, " + keysym + ", focusortogglematchingscratch, {.v = " + sp.name + "}},";

  renderScratchSection =
    name: lines:
    if lines == [ ] then
      "    /* no scratchpads defined */"
    else
      lib.concatStringsSep "\n" lines;

  generate =
    {
      spec ? defaultSpec,
      template ? defaultTemplate,
    }:
    let
      scratchCmds = renderScratchSection "cmds" (map renderScratchCmd spec.scratchpads);
      scratchpadsByName =
        lib.listToAttrs
          (map (sp: {
            name = sp.name;
            value = sp;
          }) spec.scratchpads);
      scratchRuleOrder =
        spec.scratchRuleOrder or (map (sp: sp.name) spec.scratchpads);
      scratchKeyOrder =
        spec.scratchKeyOrder or (map (sp: sp.name) spec.scratchpads);
      scratchKeysList = map (name: renderScratchKeys scratchpadsByName.${name}) scratchKeyOrder;
      scratchKeys = renderScratchSection "keys" scratchKeysList;
      termcmd = renderCmdArray "termcmd" spec.terminal.argv;
      menucmd = renderCmdArray "menucmd" spec.menu.argv;
      rules =
        let
          baseRules = map renderRule spec.rules;
          scratchRules = map (name: renderScratchRule scratchpadsByName.${name}) scratchRuleOrder;
          spacedRules =
            if scratchRules == [ ] then baseRules else baseRules ++ [ "" ] ++ scratchRules;
        in
        renderScratchSection "rules" spacedRules;
      replacements = {
        "@@TERMCMD@@" = termcmd;
        "@@MENUCMD@@" = menucmd;
        "@@SCRATCH_CMDS@@" = scratchCmds;
        "@@RULES@@" = rules;
        "@@SCRATCH_KEYS@@" = scratchKeys;
      };
      applyReplacement =
        acc: key:
        lib.replaceStrings [ key ] [ replacements.${key} ] acc;
    in
    lib.foldl applyReplacement template (lib.attrNames replacements);
in
{
  inherit defaultTemplate defaultSpec generate;
}
