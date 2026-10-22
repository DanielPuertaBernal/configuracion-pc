-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Terminals: 5% transparency (95% opacity), active and inactive.
o.window({ tag = "terminal" }, { tag = "-default-opacity", opacity = "0.95 0.95" })

-- File manager: same opacity as terminals.
o.window("org.gnome.Nautilus", { tag = "-default-opacity", opacity = "0.95 0.95" })

-- FreeRDP (RDPUCO): tile instead of floating so the remote desktop fills the window.
o.window("com.freerdp.client.sdl3", { tile = true, tag = "-default-opacity", opacity = "1.0 override 1.0 override" })
