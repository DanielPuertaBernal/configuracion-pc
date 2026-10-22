import QtQuick

// A cat chases a mouse back and forth. When it pounces, a heart pops up
// and the mouse scurries back in from the far side.
Item {
  id: scene

  property var bar
  property int trackWidth: 220
  readonly property string tooltip: "Mice caught: " + caught

  readonly property real catSize: Math.max(10, height * 0.8)
  readonly property real mouseSize: Math.max(6, height * 0.42)
  readonly property real minX: mouseSize
  readonly property real maxX: trackWidth - mouseSize

  property real mouseX: trackWidth * 0.7
  property real mouseDir: 1
  property real catX: catSize
  property real catDir: 1
  property bool mouseAlive: true
  property real popAge: -1
  property real popX: 0
  property real phase: 0
  property int caught: 0

  function respawnMouse() {
    const farRight = catX < trackWidth / 2
    mouseX = farRight ? maxX - Math.random() * trackWidth * 0.2 : minX + Math.random() * trackWidth * 0.2
    mouseDir = farRight ? -1 : 1
    mouseAlive = true
  }

  function step(dt) {
    phase += dt * 16
    if (popAge >= 0) popAge += dt
    if (popAge > 1) popAge = -1
    if (!mouseAlive) return

    const gap = mouseX - catX
    const scared = Math.abs(gap) < catSize * 1.6
    if (scared) mouseDir = gap >= 0 ? 1 : -1
    else if (Math.random() < dt * 0.7) mouseDir = -mouseDir

    mouseX += mouseDir * (scared ? 72 : 38) * dt
    if (mouseX <= minX) { mouseX = minX; mouseDir = 1 }
    if (mouseX >= maxX) { mouseX = maxX; mouseDir = -1 }

    const move = Math.sign(gap) * Math.min(Math.abs(gap), 78 * dt)
    catX = Math.max(catSize / 2, Math.min(trackWidth - catSize / 2, catX + move))
    if (Math.abs(move) > 0.01) catDir = Math.sign(move)

    if (Math.abs(mouseX - catX) < catSize * 0.45) {
      mouseAlive = false
      caught++
      popAge = 0
      popX = catX
      respawnTimer.restart()
    }
  }

  Timer {
    interval: 33
    repeat: true
    running: scene.visible
    onTriggered: {
      scene.step(interval / 1000)
      canvas.requestPaint()
    }
  }

  Timer {
    id: respawnTimer
    interval: 1200
    onTriggered: scene.respawnMouse()
  }

  Canvas {
    id: canvas
    anchors.fill: parent

    // Sprites are drawn facing right around a local origin at their feet center.
    function drawMouse(ctx, s, phase) {
      ctx.strokeStyle = "#bac2de"
      ctx.lineWidth = Math.max(1, s / 10)
      ctx.beginPath()
      ctx.moveTo(-s * 0.45, -s * 0.25)
      ctx.quadraticCurveTo(-s * 0.9, -s * 0.25 + Math.sin(phase) * s * 0.25, -s * 1.1, -s * 0.6)
      ctx.stroke()

      ctx.fillStyle = "#bac2de"
      ctx.beginPath()
      ctx.ellipse(-s * 0.5, -s * 0.6, s, s * 0.6)
      ctx.fill()
      ctx.beginPath()
      ctx.moveTo(s * 0.3, -s * 0.55)
      ctx.lineTo(s * 0.75, -s * 0.25)
      ctx.lineTo(s * 0.3, -s * 0.05)
      ctx.fill()

      ctx.fillStyle = "#f5c2e7"
      ctx.beginPath()
      ctx.arc(s * 0.22, -s * 0.62, s * 0.18, 0, Math.PI * 2)
      ctx.fill()
      ctx.fillStyle = "#11111b"
      ctx.fillRect(s * 0.42, -s * 0.38, Math.max(1, s * 0.1), Math.max(1, s * 0.1))
    }

    function drawCat(ctx, s, phase) {
      const color = "#fab387"
      ctx.strokeStyle = color
      ctx.fillStyle = color
      ctx.lineWidth = Math.max(1, s / 12)

      ctx.beginPath()
      ctx.moveTo(-s * 0.4, -s * 0.4)
      ctx.quadraticCurveTo(-s * 0.7, -s * 0.5, -s * 0.6, -s * (0.85 + Math.sin(phase * 0.5) * 0.08))
      ctx.stroke()

      const swing = Math.sin(phase) * s * 0.1
      for (const [lx, dir] of [[-s * 0.3, 1], [-s * 0.15, -1], [s * 0.15, -1], [s * 0.3, 1]]) {
        ctx.beginPath()
        ctx.moveTo(lx, -s * 0.3)
        ctx.lineTo(lx + swing * dir, 0)
        ctx.stroke()
      }

      ctx.beginPath()
      ctx.ellipse(-s * 0.45, -s * 0.58, s * 0.85, s * 0.34)
      ctx.fill()

      const hx = s * 0.4
      const hy = -s * 0.62
      const hr = s * 0.22
      ctx.beginPath()
      ctx.arc(hx, hy, hr, 0, Math.PI * 2)
      ctx.fill()
      ctx.beginPath()
      ctx.moveTo(hx - hr * 0.9, hy - hr * 0.4)
      ctx.lineTo(hx - hr * 0.5, hy - hr * 1.6)
      ctx.lineTo(hx - hr * 0.1, hy - hr * 0.8)
      ctx.moveTo(hx + hr * 0.1, hy - hr * 0.8)
      ctx.lineTo(hx + hr * 0.6, hy - hr * 1.6)
      ctx.lineTo(hx + hr * 0.95, hy - hr * 0.4)
      ctx.fill()

      ctx.fillStyle = "#11111b"
      ctx.fillRect(hx + hr * 0.3, hy - hr * 0.3, Math.max(1, hr * 0.3), Math.max(1, hr * 0.35))
    }

    onPaint: {
      const ctx = getContext("2d")
      const ground = height - Math.max(2, height * 0.12)
      ctx.reset()

      if (scene.mouseAlive) {
        ctx.save()
        ctx.translate(scene.mouseX, ground)
        ctx.scale(scene.mouseDir < 0 ? -1 : 1, 1)
        drawMouse(ctx, scene.mouseSize, scene.phase)
        ctx.restore()
      }

      ctx.save()
      ctx.translate(scene.catX, ground)
      ctx.scale(scene.catDir < 0 ? -1 : 1, 1)
      drawCat(ctx, scene.catSize, scene.phase)
      ctx.restore()

      if (scene.popAge >= 0) {
        ctx.globalAlpha = 1 - scene.popAge
        ctx.fillStyle = "#f38ba8"
        const s = Math.max(3, height * 0.14)
        const x = scene.popX
        const y = height * 0.35 - scene.popAge * height * 0.3
        ctx.beginPath()
        ctx.arc(x - s / 2, y, s / 2, Math.PI, 0)
        ctx.arc(x + s / 2, y, s / 2, Math.PI, 0)
        ctx.lineTo(x, y + s * 1.2)
        ctx.closePath()
        ctx.fill()
        ctx.globalAlpha = 1
      }
    }
  }
}
