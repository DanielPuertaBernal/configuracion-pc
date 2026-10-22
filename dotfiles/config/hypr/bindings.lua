-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Remote desktop passthrough: SUPER+ALT+R toggles a submap with no bindings, so every
-- key (including SUPER combos like SUPER+SHIFT+S) reaches the focused RDP window.
-- Press SUPER+ALT+R again to return to normal Hyprland bindings.
-- Emergency exit: hyprctl dispatch 'hl.dsp.submap("reset")'
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("notify-send -t 2000 'Remote passthrough ON' 'SUPER+ALT+R to exit'"))
hl.bind("SUPER + ALT + R", hl.dsp.submap("passthru"))
hl.define_submap("passthru", function()
  hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("notify-send -t 2000 'Remote passthrough OFF'"))
  hl.bind("SUPER + ALT + R", hl.dsp.submap("reset"))
end)
