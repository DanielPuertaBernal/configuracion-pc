import QtQuick

// Claude's pixel mascot chases a bug back and forth across a strip of the bar.
// When it catches the bug, the bug pops and respawns somewhere else.
Item {
  id: root

  property var bar
  property int trackWidth: 220
  readonly property string tooltip: "Bugs fixed: " + bugsFixed
  readonly property real spriteSize: Math.min(18, height - 6)
  readonly property color claudeColor: "#d97757"
  readonly property color bugColor: "#a6e3a1"

  // Positions are sprite centers in pixels along the track.
  property real bugX: trackWidth * 0.75
  property real bugDir: 1
  property real bugSpeed: 45
  property real hunterX: 40
  property real hunterDir: 1
  readonly property int pixel: Math.max(2, Math.floor((height - 10) / 9))
  readonly property real hunterHalf: 8 * pixel
  property bool bugAlive: true
  property int bugsFixed: 0
  property real legPhase: 0

  readonly property real minX: spriteSize / 2
  readonly property real maxX: trackWidth - spriteSize / 2

  function respawnBug() {
    // Drop the bug on the far side of the hunter so the chase restarts.
    const farRight = hunterX < trackWidth / 2
    bugX = farRight ? maxX - Math.random() * trackWidth * 0.2 : minX + Math.random() * trackWidth * 0.2
    bugDir = farRight ? -1 : 1
    bugAlive = true
  }

  function step(dt) {
    legPhase += dt * 18

    if (!bugAlive) return

    const gap = bugX - hunterX
    const scared = Math.abs(gap) < hunterHalf + spriteSize * 2

    // Wander, occasionally changing its mind; flee when the hunter gets close.
    if (scared) bugDir = gap >= 0 ? 1 : -1
    else if (Math.random() < dt * 0.6) bugDir = -bugDir
    bugSpeed = scared ? 80 : 45

    bugX += bugDir * bugSpeed * dt
    if (bugX <= minX) { bugX = minX; bugDir = 1 }
    if (bugX >= maxX) { bugX = maxX; bugDir = -1 }

    // The hunter is slightly faster than a scared bug, so it always wins eventually.
    const hunterSpeed = 70
    const move = Math.sign(gap) * Math.min(Math.abs(gap), hunterSpeed * dt)
    hunterX = Math.max(hunterHalf, Math.min(trackWidth - hunterHalf, hunterX + move))
    if (Math.abs(move) > 0.01) hunterDir = Math.sign(move)

    if (Math.abs(bugX - hunterX) < hunterHalf * 0.7) {
      bugAlive = false
      bugsFixed++
      pop.restart()
      respawnTimer.restart()
    }
  }

  Timer {
    interval: 33
    repeat: true
    running: root.visible
    onTriggered: root.step(interval / 1000)
  }

  Timer {
    id: respawnTimer
    interval: 1400
    onTriggered: root.respawnBug()
  }

  // Bug
  Canvas {
    id: bugSprite
    width: root.spriteSize
    height: root.spriteSize
    x: root.bugX - width / 2
    y: (root.height - height) / 2
    visible: root.bugAlive
    transform: Scale { origin.x: bugSprite.width / 2; xScale: root.bugDir < 0 ? -1 : 1 }

    property real phase: root.legPhase
    onPhaseChanged: requestPaint()

    onPaint: {
      const ctx = getContext("2d")
      const s = width
      ctx.reset()
      ctx.strokeStyle = root.bugColor
      ctx.fillStyle = root.bugColor
      ctx.lineWidth = Math.max(1, s / 12)

      // Legs, alternating like a scuttle.
      const swing = Math.sin(phase) * s * 0.08
      for (let i = -1; i <= 1; i++) {
        const lx = s * 0.45 + i * s * 0.16
        const off = (i % 2 === 0 ? swing : -swing)
        ctx.beginPath()
        ctx.moveTo(lx, s * 0.5); ctx.lineTo(lx + off, s * 0.18)
        ctx.moveTo(lx, s * 0.5); ctx.lineTo(lx - off, s * 0.82)
        ctx.stroke()
      }

      // Body and head.
      ctx.beginPath()
      ctx.ellipse(s * 0.18, s * 0.32, s * 0.52, s * 0.36)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(s * 0.78, s * 0.5, s * 0.12, 0, Math.PI * 2)
      ctx.fill()

      // Antennae.
      ctx.beginPath()
      ctx.moveTo(s * 0.86, s * 0.44); ctx.lineTo(s * 0.98, s * 0.28)
      ctx.moveTo(s * 0.86, s * 0.56); ctx.lineTo(s * 0.98, s * 0.72)
      ctx.stroke()
    }
  }

  // Hunter: Claude's pixel mascot, drawn from a 16x7 grid. Eyes are holes in the body.
  Canvas {
    id: hunter
    readonly property var rows: [
      [[3, 12]],
      [[3, 4], [6, 9], [11, 12]],
      [[3, 4], [6, 9], [11, 12]],
      [[1, 14]],
      [[1, 14]],
      [[3, 12]]
    ]
    // Two leg frames so it scuttles while moving.
    readonly property var legs: [[4, 6, 9, 11], [3, 5, 10, 12]]
    property int frame: Math.floor(root.legPhase / 3) % 2

    width: 16 * root.pixel
    height: 7 * root.pixel
    x: root.hunterX - width / 2
    y: (root.height - height) / 2 - (frame === 1 ? 1 : 0)
    transform: Scale { origin.x: hunter.width / 2; xScale: root.hunterDir < 0 ? -1 : 1 }

    onFrameChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
      const ctx = getContext("2d")
      const p = root.pixel
      ctx.reset()
      ctx.fillStyle = root.claudeColor
      for (let y = 0; y < rows.length; y++)
        for (const span of rows[y]) ctx.fillRect(span[0] * p, y * p, (span[1] - span[0] + 1) * p, p)
      for (const lx of legs[frame]) ctx.fillRect(lx * p, 6 * p, p, p)
    }
  }

  // Catch feedback.
  Text {
    id: popText
    text: "+1"
    color: root.bugColor
    font.family: root.bar ? root.bar.fontFamily : ""
    font.pixelSize: 10
    font.bold: true
    x: root.hunterX - width / 2
    y: 0
    opacity: 0

    SequentialAnimation {
      id: pop
      ParallelAnimation {
        NumberAnimation { target: popText; property: "opacity"; from: 1; to: 0; duration: 900 }
        NumberAnimation { target: popText; property: "y"; from: root.height / 2 - 6; to: -4; duration: 900; easing.type: Easing.OutCubic }
      }
    }
  }
}
