# danso.edgeviz — edge audio visualizer

Audio-reactive bars that grow inward from every screen edge, driven by a
private `cava` process (`cava.conf`, PipeWire input, raw ASCII output).
The overlay is click-through and fades out after a few seconds of silence.

## Tweak

All knobs live at the top of `Service.qml`; saving reloads the plugin.

| Property | Effect |
|---|---|
| `horizontalBars` / `verticalBars` | bar count on top+bottom / left+right edges |
| `depth` | max bar length in px (how far bars reach inward) |
| `thicknessRatio` | bar thickness relative to its slot (0–1) |
| `hueSpread` | hue shift from edge center to corners (0 = single color) |
| `glowStrength` | opacity of the soft edge aura at full volume |
| `showTop` / `showBottom` / `showLeft` / `showRight` | toggle edges |
| `silenceMs` | silence before fading out |
| `loudnessCurve` | <1 lifts quiet audio while keeping louder = taller |
| `kickRatio` / `kickBoost` / `kickDecay` | beat detection threshold, bass pulse size, pulse length |
| `barDecay` | how fast bars fall after a hit (lower = snappier) |

Loudness is not normalized: `cava.conf` uses `autosens = 0` with a fixed
`sensitivity`; raise it if bars are too short at full volume.

Colors follow the active Omarchy theme accent (`Color.accent`) automatically.
For spectrum resolution or frame rate, edit `bars` / `framerate` in `cava.conf`.

## Disable

    omarchy plugin disable danso.edgeviz

Re-enable with `omarchy plugin enable danso.edgeviz`.
