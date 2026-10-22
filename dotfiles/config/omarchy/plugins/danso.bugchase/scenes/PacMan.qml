import QtQuick

// A yellow chomper eats a row of dots while ghosts trail behind it.
// Eating the power pellet turns the ghosts blue and sends them drifting back.
Item {
  id: scene

  property var bar
  property int trackWidth: 220
  readonly property string tooltip: "Dots eaten: " + dotsEaten

  readonly property real radius: Math.max(4, Math.min(9, height * 0.32))
  readonly property real dotSpacing: 12
  readonly property real pacSpeed: 55
  readonly property var ghostColors: ["#ff5555", "#ffb8ff", "#00ffff"]

  property real pacX: -radius
  property var ghostX: [-40, -60, -80]
  property var eaten: []
  property int pelletIndex: 0
  property real frightened: 0
  property real time: 0
  property int dotsEaten: 0

  function resetLap() {
    const count = Math.max(1, Math.floor((trackWidth - dotSpacing) / dotSpacing))
    const fresh = []
    for (let i = 0; i < count; i++) fresh.push(false)
    eaten = fresh
    pelletIndex = Math.floor(count * 0.55)
    pacX = -radius
    ghostX = ghostColors.map((_, i) => pacX - radius * 3 - i * radius * 2.4)
    frightened = 0
  }

  function step(dt) {
    time += dt
    pacX += pacSpeed * dt

    for (let i = 0; i < eaten.length; i++) {
      if (!eaten[i] && pacX >= dotSpacing + i * dotSpacing) {
        eaten[i] = true
        dotsEaten++
        if (i === pelletIndex) frightened = 3.5
      }
    }

    frightened = Math.max(0, frightened - dt)
    const next = ghostX.slice()
    for (let g = 0; g < next.length; g++) {
      if (frightened > 0) {
        next[g] -= 25 * dt
      } else {
        // Ghosts close in quickly but always stay a little behind.
        const limit = pacX - radius * 2.6 - g * radius * 2.4
        next[g] = Math.min(next[g] + 75 * dt, limit)
      }
    }
    ghostX = next

    if (pacX - radius > trackWidth && Math.max(...ghostX) - radius > trackWidth) resetLap()
    else if (pacX - radius > trackWidth + radius * 10) resetLap()
  }

  Component.onCompleted: resetLap()
  onTrackWidthChanged: resetLap()

  Timer {
    interval: 33
    repeat: true
    running: scene.visible
    onTriggered: {
      scene.step(interval / 1000)
      canvas.requestPaint()
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent

    function drawGhost(ctx, x, y, r, color, phase) {
      ctx.fillStyle = color
      ctx.beginPath()
      ctx.arc(x, y - r * 0.15, r, Math.PI, 0)
      ctx.lineTo(x + r, y + r)
      // Wavy skirt with three scallops that shift as it moves.
      const w = (2 * r) / 3
      for (let i = 0; i < 3; i++) {
        const sx = x + r - i * w
        const dip = (i + Math.floor(phase)) % 2 === 0 ? r * 0.3 : r * 0.15
        ctx.lineTo(sx - w / 2, y + r - dip)
        ctx.lineTo(sx - w, y + r)
      }
      ctx.closePath()
      ctx.fill()

      if (scene.frightened > 0) {
        ctx.fillStyle = "#ffe0c0"
        ctx.fillRect(x - r * 0.45, y - r * 0.3, r * 0.25, r * 0.25)
        ctx.fillRect(x + r * 0.2, y - r * 0.3, r * 0.25, r * 0.25)
        return
      }
      ctx.fillStyle = "#ffffff"
      for (const ex of [-0.38, 0.32]) {
        ctx.beginPath()
        ctx.arc(x + ex * r, y - r * 0.25, r * 0.28, 0, Math.PI * 2)
        ctx.fill()
      }
      ctx.fillStyle = "#2121de"
      for (const ex of [-0.3, 0.4]) {
        ctx.beginPath()
        ctx.arc(x + ex * r, y - r * 0.22, r * 0.14, 0, Math.PI * 2)
        ctx.fill()
      }
    }

    onPaint: {
      const ctx = getContext("2d")
      const r = scene.radius
      const cy = height / 2
      ctx.reset()

      ctx.fillStyle = "#ffb897"
      for (let i = 0; i < scene.eaten.length; i++) {
        if (scene.eaten[i]) continue
        const dx = scene.dotSpacing + i * scene.dotSpacing
        const big = i === scene.pelletIndex
        const s = big ? Math.max(4, r * 0.8) : 2
        if (big && Math.floor(scene.time * 4) % 2 === 1) continue
        ctx.beginPath()
        ctx.arc(dx, cy, s / 2 + (big ? 0.5 : 0), 0, Math.PI * 2)
        ctx.fill()
      }

      const blink = scene.frightened > 0 && scene.frightened < 1 && Math.floor(scene.time * 8) % 2 === 0
      for (let g = 0; g < scene.ghostX.length; g++) {
        const color = scene.frightened > 0 ? (blink ? "#ffffff" : "#2121de") : scene.ghostColors[g]
        drawGhost(ctx, scene.ghostX[g], cy, r, color, scene.time * 8)
      }

      const mouth = Math.abs(Math.sin(scene.time * 12)) * 0.28 * Math.PI
      ctx.fillStyle = "#ffd700"
      ctx.beginPath()
      ctx.moveTo(scene.pacX, cy)
      ctx.arc(scene.pacX, cy, r, mouth, Math.PI * 2 - mouth)
      ctx.closePath()
      ctx.fill()
    }
  }
}
