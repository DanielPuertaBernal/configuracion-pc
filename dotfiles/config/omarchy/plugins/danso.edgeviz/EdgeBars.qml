import QtQuick

// One screen edge worth of bars. The spectrum is mirrored around the middle
// of the edge, so bass sits at the center and highs fade toward the corners.
Item {
  id: root

  property string edge: "bottom" // top | bottom | left | right
  property int count: 24
  property var levels: []
  property real energy: 0
  property real depth: 70
  property real thicknessRatio: 0.55
  property color baseColor: "#89b4fa"
  property real hueSpread: 0.12
  property real glowStrength: 0.35

  readonly property bool horizontal: edge === "top" || edge === "bottom"
  readonly property bool edgeAtStart: edge === "top" || edge === "left"
  readonly property real span: horizontal ? width : height
  readonly property real slot: count > 0 ? span / count : span

  function tintFor(distance, alpha) {
    const hue = baseColor.hslHue < 0 ? 0 : baseColor.hslHue
    const shifted = ((hue + distance * hueSpread) % 1 + 1) % 1
    return Qt.hsla(shifted, baseColor.hslSaturation, baseColor.hslLightness, alpha)
  }

  // Soft aura hugging the edge; its strength follows overall loudness.
  Rectangle {
    readonly property real glowDepth: root.depth * 0.6
    x: root.edge === "right" ? root.width - glowDepth : 0
    y: root.edge === "bottom" ? root.height - glowDepth : 0
    width: root.horizontal ? root.width : glowDepth
    height: root.horizontal ? glowDepth : root.height
    opacity: Math.min(1, root.energy) * root.glowStrength
    gradient: Gradient {
      orientation: root.horizontal ? Gradient.Vertical : Gradient.Horizontal
      GradientStop { position: 0; color: root.edgeAtStart ? root.tintFor(0, 1) : root.tintFor(0, 0) }
      GradientStop { position: 1; color: root.edgeAtStart ? root.tintFor(0, 0) : root.tintFor(0, 1) }
    }
  }

  Repeater {
    model: root.count

    Rectangle {
      required property int index
      readonly property real t: root.count > 1 ? index / (root.count - 1) : 0.5
      readonly property real distance: Math.abs(t - 0.5) * 2
      readonly property real level: {
        const n = root.levels.length
        return n ? root.levels[Math.min(n - 1, Math.round(distance * (n - 1)))] : 0
      }
      readonly property real length: Math.max(2, level * root.depth)
      readonly property real thickness: Math.max(2, root.slot * root.thicknessRatio)
      readonly property color tint: root.tintFor(distance, 1)
      readonly property color fade: root.tintFor(distance, 0)

      x: root.horizontal ? index * root.slot + (root.slot - thickness) / 2
                         : (root.edge === "left" ? 0 : root.width - length)
      y: root.horizontal ? (root.edge === "top" ? 0 : root.height - length)
                         : index * root.slot + (root.slot - thickness) / 2
      width: root.horizontal ? thickness : length
      height: root.horizontal ? length : thickness
      radius: thickness / 2

      gradient: Gradient {
        orientation: root.horizontal ? Gradient.Vertical : Gradient.Horizontal
        // Solid near the edge, fading only over the inner tip.
        GradientStop { position: 0; color: root.edgeAtStart ? tint : fade }
        GradientStop { position: root.edgeAtStart ? 0.6 : 0.4; color: tint }
        GradientStop { position: 1; color: root.edgeAtStart ? fade : tint }
      }
    }
  }
}
