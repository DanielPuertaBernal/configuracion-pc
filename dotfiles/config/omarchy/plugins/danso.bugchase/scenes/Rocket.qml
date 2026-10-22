import QtQuick

// A little rocket flies through a scrolling starfield, switching lanes to
// dodge tumbling asteroids.
Item {
  id: scene

  property var bar
  property int trackWidth: 220
  readonly property string tooltip: "Asteroids dodged: " + dodged

  readonly property real rocketX: Math.min(60, trackWidth * 0.22)
  readonly property real rocketLen: Math.max(12, height * 0.75)
  readonly property real asteroidSpeed: 70
  readonly property var lanes: [height * 0.3, height * 0.7]

  property int targetLane: 0
  property real rocketY: height * 0.3
  property var asteroids: []
  property var stars: []
  property real spawnIn: 0.5
  property real time: 0
  property int dodged: 0

  function resetStars() {
    const list = []
    for (let i = 0; i < Math.max(8, trackWidth / 12); i++)
      list.push({ x: Math.random() * trackWidth, y: Math.random() * height, far: Math.random() < 0.6 })
    stars = list
  }

  function step(dt) {
    time += dt

    for (const s of stars) {
      s.x -= (s.far ? 12 : 30) * dt
      if (s.x < 0) { s.x += trackWidth; s.y = Math.random() * height }
    }

    spawnIn -= dt
    const last = asteroids.length ? asteroids[asteroids.length - 1] : null
    if (spawnIn <= 0 && (!last || last.x < trackWidth - 50)) {
      asteroids.push({
        x: trackWidth + 8,
        lane: Math.random() < 0.5 ? 0 : 1,
        size: Math.max(3, height * (0.13 + Math.random() * 0.07)),
        spin: Math.random() * Math.PI,
        passed: false
      })
      spawnIn = 0.7 + Math.random() * 1.1
    }

    // Steer away from the nearest asteroid still ahead of the nose.
    let nearest = null
    for (const a of asteroids) {
      if (a.x + a.size > rocketX - rocketLen / 2 && (!nearest || a.x < nearest.x)) nearest = a
    }
    if (nearest && nearest.x - rocketX < 70 && nearest.lane === targetLane) targetLane = 1 - targetLane

    for (const a of asteroids) {
      a.x -= asteroidSpeed * dt
      a.spin += dt * 2
      if (!a.passed && a.x + a.size < rocketX - rocketLen / 2) { a.passed = true; dodged++ }
    }
    asteroids = asteroids.filter(a => a.x > -a.size * 2)

    rocketY += (lanes[targetLane] - rocketY) * Math.min(1, dt * 9)
  }

  Component.onCompleted: resetStars()
  onTrackWidthChanged: resetStars()
  onHeightChanged: { resetStars(); rocketY = lanes[targetLane] }

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

    onPaint: {
      const ctx = getContext("2d")
      ctx.reset()

      for (const s of scene.stars) {
        ctx.fillStyle = s.far ? "#585b70" : "#cdd6f4"
        ctx.fillRect(s.x, s.y, 1, 1)
      }

      ctx.fillStyle = "#7f849c"
      for (const a of scene.asteroids) {
        const cy = scene.lanes[a.lane]
        ctx.beginPath()
        for (let i = 0; i < 7; i++) {
          const ang = a.spin + (i / 7) * Math.PI * 2
          const r = a.size * (i % 2 === 0 ? 1 : 0.72)
          const px = a.x + Math.cos(ang) * r
          const py = cy + Math.sin(ang) * r
          if (i === 0) ctx.moveTo(px, py)
          else ctx.lineTo(px, py)
        }
        ctx.closePath()
        ctx.fill()
      }

      const L = scene.rocketLen
      const H = L * 0.36
      const x = scene.rocketX
      const y = scene.rocketY

      const flame = L * (0.25 + Math.random() * 0.2)
      ctx.fillStyle = "#fab387"
      ctx.beginPath()
      ctx.moveTo(x - L / 2, y - H * 0.35)
      ctx.lineTo(x - L / 2 - flame, y)
      ctx.lineTo(x - L / 2, y + H * 0.35)
      ctx.fill()
      ctx.fillStyle = "#f9e2af"
      ctx.beginPath()
      ctx.moveTo(x - L / 2, y - H * 0.18)
      ctx.lineTo(x - L / 2 - flame * 0.55, y)
      ctx.lineTo(x - L / 2, y + H * 0.18)
      ctx.fill()

      ctx.fillStyle = "#f38ba8"
      ctx.beginPath()
      ctx.moveTo(x - L * 0.45, y - H / 2)
      ctx.lineTo(x - L * 0.6, y - H)
      ctx.lineTo(x - L * 0.2, y - H / 2)
      ctx.moveTo(x - L * 0.45, y + H / 2)
      ctx.lineTo(x - L * 0.6, y + H)
      ctx.lineTo(x - L * 0.2, y + H / 2)
      ctx.fill()

      ctx.fillStyle = "#cdd6f4"
      ctx.fillRect(x - L / 2, y - H / 2, L * 0.7, H)
      ctx.fillStyle = "#f38ba8"
      ctx.beginPath()
      ctx.moveTo(x + L * 0.2, y - H / 2)
      ctx.lineTo(x + L / 2, y)
      ctx.lineTo(x + L * 0.2, y + H / 2)
      ctx.fill()

      ctx.fillStyle = "#89b4fa"
      ctx.beginPath()
      ctx.arc(x + L * 0.02, y, H * 0.26, 0, Math.PI * 2)
      ctx.fill()
    }
  }
}
