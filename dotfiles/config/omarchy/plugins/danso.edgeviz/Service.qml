import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Edge audio visualizer: a click-through overlay per screen with bars that
// grow inward from every edge, fed by a private cava process.
Scope {
  id: root

  // ---- Tweakables (see README.md) ----
  readonly property int horizontalBars: 32  // bars on top and bottom edges
  readonly property int verticalBars: 18    // bars on left and right edges
  readonly property real depth: 90          // max bar length in px
  readonly property real thicknessRatio: 0.5 // bar thickness vs slot width
  readonly property real hueSpread: 0.15    // hue shift from center to corners
  readonly property real glowStrength: 0.35 // edge aura opacity at full volume
  readonly property bool showTop: false
  readonly property bool showBottom: false
  readonly property bool showLeft: true
  readonly property bool showRight: true
  readonly property int silenceMs: 3000     // fade out after this much silence
  readonly property real silenceThreshold: 0.002
  readonly property int bassBands: 4        // lowest cava bands treated as kick
  readonly property real kickRatio: 1.35    // bass jump vs running average that counts as a hit
  readonly property real kickBoost: 0.6     // extra height a kick adds to bass bars
  readonly property real kickDecay: 0.82    // per-frame kick fade (lower = shorter flash)
  readonly property real barDecay: 0.6      // per-frame bar fall (lower = faster drop)
  readonly property real loudnessCurve: 0.6 // <1 lifts quiet audio; ordering by loudness is kept

  property var levels: []
  property real energy: 0
  property bool active: false
  property double lastSoundAt: 0
  property var smoothed: []
  property real bassAverage: 0
  property real kick: 0
  property double lastKickAt: 0

  // Instant attack, quick decay, plus a short kick pulse on bass hits so
  // beats read clearly. Levels are not normalized: louder audio = taller bars.
  function process(values) {
    const now = Date.now()
    let bass = 0
    for (let i = 0; i < root.bassBands && i < values.length; i++) bass += values[i]
    bass /= Math.min(root.bassBands, values.length)
    if (bass > 0.04 && bass > root.bassAverage * root.kickRatio && now - root.lastKickAt > 120) {
      root.kick = 1
      root.lastKickAt = now
    } else {
      root.kick *= root.kickDecay
    }
    root.bassAverage = root.bassAverage * 0.92 + bass * 0.08

    const prev = root.smoothed
    const next = []
    let sum = 0
    for (let i = 0; i < values.length; i++) {
      const old = prev.length > i ? prev[i] : 0
      const raw = Math.pow(values[i], root.loudnessCurve)
      const v = raw >= old ? raw : old * root.barDecay + raw * (1 - root.barDecay)
      next.push(v)
      sum += v
    }
    root.smoothed = next

    const out = []
    const n = next.length
    for (let i = 0; i < n; i++) {
      const bassWeight = Math.max(0, 1 - i / (n * 0.35))
      // The kick scales with real bass level, so quiet playback stays small.
      out.push(Math.min(1, next[i] * (1 + root.kick * root.kickBoost * bassWeight)))
    }
    root.levels = out
    root.energy = Math.min(1, (sum / n) * 2 + root.kick * bass)
  }

  Process {
    id: cava
    running: true
    command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function(line) {
        const values = line.split(";").filter(v => v !== "").map(v => Number(v) / 1000)
        if (!values.length) return
        let peak = 0
        for (let i = 0; i < values.length; i++) peak = Math.max(peak, values[i])
        if (peak > root.silenceThreshold) {
          root.lastSoundAt = Date.now()
          root.active = true
        }
        // Skip redraws while silent and already faded out.
        if (!root.active) return
        root.process(values)
      }
    }
    onExited: restartTimer.start()
  }

  Timer {
    id: restartTimer
    interval: 3000
    onTriggered: cava.running = true
  }

  Timer {
    interval: 500
    repeat: true
    running: root.active
    onTriggered: if (Date.now() - root.lastSoundAt > root.silenceMs) root.active = false
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: content.opacity > 0.01
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      WlrLayershell.namespace: "danso-edgeviz"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Normal // respect the top bar: stay below it
      exclusiveZone: 0
      // Empty input region: the overlay never intercepts pointer input.
      mask: Region {}

      Item {
        id: content
        anchors.fill: parent
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        component Edge: EdgeBars {
          anchors.fill: parent
          levels: root.levels
          energy: root.energy
          depth: root.depth
          thicknessRatio: root.thicknessRatio
          baseColor: Color.accent
          hueSpread: root.hueSpread
          glowStrength: root.glowStrength
        }

        Edge { edge: "top"; count: root.horizontalBars; visible: root.showTop }
        Edge { edge: "bottom"; count: root.horizontalBars; visible: root.showBottom }
        Edge { edge: "left"; count: root.verticalBars; visible: root.showLeft }
        Edge { edge: "right"; count: root.verticalBars; visible: root.showRight }
      }
    }
  }
}
