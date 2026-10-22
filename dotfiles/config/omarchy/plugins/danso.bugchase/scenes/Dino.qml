import QtQuick

// A pixel dinosaur runs along the ground and hops over cacti as they scroll by.
Item {
  id: scene

  property var bar
  property int trackWidth: 220
  readonly property string tooltip: "Cacti jumped: " + jumps

  // Sprite grid; "X" is a filled pixel. Two leg frames alternate while running.
  readonly property var body: [
    "......XXXX..",
    ".....XX.XXX.",
    ".....XXXXXX.",
    ".....XXX....",
    "X...XXXXX...",
    "X..XXXXXXX..",
    "XX.XXXXX.X..",
    "XXXXXXXX....",
    ".XXXXXXX....",
    "..XXXXX....."
  ]
  readonly property var legFrames: [
    ["..X...X.....", "..XX..XX...."],
    ["..X..X......", "..XX.......X"]
  ]
  readonly property color dinoColor: "#a6e3a1"
  readonly property color cactusColor: "#94e2d5"

  readonly property int pixel: Math.max(1, Math.floor((height - 4) / 24))
  readonly property real dinoW: 12 * pixel
  readonly property real dinoH: 12 * pixel
  readonly property real groundY: height - 2
  readonly property real dinoX: Math.min(40, trackWidth * 0.18)
  readonly property real cactusSpeed: 70
  readonly property real airTime: 0.6
  // Highest the dino can rise while staying inside the bar.
  readonly property real apex: Math.max(4, groundY - dinoH - 1)

  property real lift: 0
  property real vy: 0
  property var cacti: []
  property var pebbles: []
  property real nextGap: 80
  property real time: 0
  property int jumps: 0

  function resetPebbles() {
    const list = []
    for (let i = 0; i < trackWidth / 10; i++) list.push({ x: Math.random() * trackWidth, w: Math.random() < 0.5 ? 1 : 2 })
    pebbles = list
  }

  function step(dt) {
    time += dt
    const gravity = 8 * apex / (airTime * airTime)

    for (const p of pebbles) {
      p.x -= cactusSpeed * dt
      if (p.x < 0) p.x += trackWidth
    }

    const last = cacti.length ? cacti[cacti.length - 1] : null
    if (!last || trackWidth - last.x > nextGap) {
      const h = Math.max(4, Math.min(apex * 0.65, height * (0.22 + Math.random() * 0.1)))
      cacti.push({ x: trackWidth + 4, h: h, w: Math.max(3, h * 0.45), counted: false })
      nextGap = 70 + Math.random() * 90
    }

    // Jump so the peak of the arc lines up with the cactus.
    const center = dinoX + dinoW / 2
    for (const c of cacti) {
      c.x -= cactusSpeed * dt
      const dist = c.x + c.w / 2 - center
      if (!c.counted && lift === 0 && dist > 0 && dist < cactusSpeed * airTime / 2) {
        c.counted = true
        vy = 4 * apex / airTime
        jumps++
      }
    }
    cacti = cacti.filter(c => c.x + c.w > 0)

    if (lift > 0 || vy > 0) {
      lift += vy * dt
      vy -= gravity * dt
      if (lift <= 0) { lift = 0; vy = 0 }
    }
  }

  Component.onCompleted: resetPebbles()
  onTrackWidthChanged: resetPebbles()

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

    function drawRows(ctx, rows, x, y, p) {
      for (let r = 0; r < rows.length; r++)
        for (let c = 0; c < rows[r].length; c++)
          if (rows[r][c] === "X") ctx.fillRect(x + c * p, y + r * p, p, p)
    }

    onPaint: {
      const ctx = getContext("2d")
      const p = scene.pixel
      const gy = scene.groundY
      ctx.reset()

      ctx.fillStyle = "#585b70"
      ctx.fillRect(0, gy, width, 1)
      for (const pb of scene.pebbles) ctx.fillRect(pb.x, gy + 1, pb.w, 1)

      ctx.fillStyle = scene.cactusColor
      for (const c of scene.cacti) {
        const top = gy - c.h
        ctx.fillRect(c.x, top, c.w, c.h)
        const armW = Math.max(1, c.w * 0.5)
        ctx.fillRect(c.x - armW, top + c.h * 0.35, armW, Math.max(1, c.h * 0.15))
        ctx.fillRect(c.x - armW, top + c.h * 0.15, Math.max(1, armW * 0.6), c.h * 0.3)
        ctx.fillRect(c.x + c.w, top + c.h * 0.25, armW, Math.max(1, c.h * 0.15))
        ctx.fillRect(c.x + c.w + armW * 0.4, top + c.h * 0.05, Math.max(1, armW * 0.6), c.h * 0.3)
      }

      const top = Math.round(gy - scene.dinoH - scene.lift)
      ctx.fillStyle = scene.dinoColor
      drawRows(ctx, scene.body, scene.dinoX, top, p)
      const legs = scene.lift > 0 ? scene.legFrames[0] : scene.legFrames[Math.floor(scene.time * 10) % 2]
      drawRows(ctx, legs, scene.dinoX, top + scene.body.length * p, p)
    }
  }
}
