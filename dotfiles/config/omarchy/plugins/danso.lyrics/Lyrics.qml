import QtQuick
import Quickshell.Services.Mpris

// Karaoke-style synced lyrics for the current Spotify track, fetched from LRCLIB.
// The current line fills with color as it is sung and scrolls to follow the highlight.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property int trackWidth: settings && settings.width ? settings.width : 400
  // Catppuccin Mocha palette, shared with the visualizer widgets.
  readonly property var palette: ["#cba6f7", "#f5c2e7", "#f38ba8", "#fab387", "#f9e2af",
                                  "#a6e3a1", "#94e2d5", "#89dceb", "#74c7ec", "#89b4fa"]

  readonly property var player: {
    const list = Mpris.players ? Mpris.players.values : []
    for (let i = 0; i < list.length; i++) {
      const name = String(list[i].identity || list[i].desktopEntry || "").toLowerCase()
      if (name.indexOf("spotify") !== -1) return list[i]
    }
    return null
  }
  readonly property bool isPlaying: player ? player.isPlaying : false
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string album: player ? (player.trackAlbum || "") : ""
  readonly property string trackKey: title + "\u0000" + artist

  // [{ time: seconds, text: string }], sorted by time. Empty when unavailable.
  property var lines: []
  property string status: "idle" // idle | loading | synced | missing
  property real position: 0
  property var cache: ({})

  readonly property int lineIndex: {
    let idx = -1
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) idx = i
      else break
    }
    return idx
  }
  readonly property string lineText: {
    if (status === "synced") return lineIndex >= 0 && lines[lineIndex].text ? lines[lineIndex].text : "♪"
    if (status === "loading") return "♪ " + title
    return title ? "♪ " + title + (artist ? " — " + artist : "") : ""
  }
  // 0..1 progress through the current line, interpolated until the next line starts.
  readonly property real lineProgress: {
    if (status !== "synced" || lineIndex < 0) return 0
    const start = lines[lineIndex].time
    const end = lineIndex + 1 < lines.length ? lines[lineIndex + 1].time : start + 5
    // Reach full highlight a bit before the next line so the last word lands in time.
    const span = Math.max(0.5, (end - start) * 0.9)
    return Math.max(0, Math.min(1, (position - start) / span))
  }
  readonly property color lineColor: palette[Math.max(0, lineIndex) % palette.length]

  visible: player !== null && title !== ""
  implicitWidth: visible ? trackWidth : 0
  implicitHeight: bar ? bar.barSize : 26

  function parseLrc(lrc) {
    const out = []
    const re = /^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/
    const raw = String(lrc || "").split("\n")
    for (let i = 0; i < raw.length; i++) {
      const m = raw[i].trim().match(re)
      if (m) out.push({ time: Number(m[1]) * 60 + Number(m[2]), text: m[3].trim() })
    }
    out.sort((a, b) => a.time - b.time)
    return out
  }

  function request(url, onDone) {
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      let data = null
      if (xhr.status === 200) {
        try { data = JSON.parse(xhr.responseText) } catch (e) { data = null }
      }
      onDone(data)
    }
    xhr.open("GET", url)
    xhr.setRequestHeader("User-Agent", "danso.lyrics (omarchy bar widget)")
    xhr.send()
  }

  function fetchLyrics() {
    lines = []
    if (!title) { status = "idle"; return }
    const key = trackKey
    if (cache[key] !== undefined) {
      lines = cache[key]
      status = lines.length > 0 ? "synced" : "missing"
      return
    }
    status = "loading"

    const finish = function(found) {
      cache[key] = found
      if (key !== root.trackKey) return // track changed while loading
      lines = found
      status = found.length > 0 ? "synced" : "missing"
    }

    const enc = encodeURIComponent
    let url = "https://lrclib.net/api/get?track_name=" + enc(title) + "&artist_name=" + enc(artist)
    if (album) url += "&album_name=" + enc(album)
    if (player && player.length > 0) url += "&duration=" + Math.round(player.length)

    request(url, function(data) {
      if (data && data.syncedLyrics) { finish(parseLrc(data.syncedLyrics)); return }
      // Exact match failed or had no timing; fall back to a looser search.
      request("https://lrclib.net/api/search?track_name=" + enc(title) + "&artist_name=" + enc(artist), function(results) {
        const hit = Array.isArray(results) ? results.find(r => r && r.syncedLyrics) : null
        finish(hit ? parseLrc(hit.syncedLyrics) : [])
      })
    })
  }

  onTrackKeyChanged: fetchLyrics()
  Component.onCompleted: fetchLyrics()

  // MPRIS position is not pushed; poll it often enough for smooth highlighting.
  Timer {
    interval: 100
    repeat: true
    running: root.visible && root.isPlaying
    onTriggered: {
      root.player.positionChanged()
      root.position = root.player.position
    }
  }

  Item {
    id: viewport
    anchors.fill: parent
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    clip: true
    opacity: root.isPlaying ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: 300 } }

    Item {
      id: line
      height: parent.height
      width: base.implicitWidth

      // Keep the highlight edge near the middle when the line is wider than the viewport.
      readonly property real overflow: Math.max(0, width - viewport.width)
      x: overflow > 0
         ? -Math.max(0, Math.min(overflow, root.lineProgress * width - viewport.width / 2))
         : (viewport.width - width) / 2
      Behavior on x { NumberAnimation { duration: 120 } }

      Text {
        id: base
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.lineText
        color: root.bar ? root.bar.barForeground : "#cdd6f4"
        opacity: 0.4
        font.family: root.bar ? root.bar.fontFamily : ""
        font.pixelSize: 13
      }

      // Same text, clipped to the sung portion.
      Item {
        height: parent.height
        width: root.status === "synced" ? base.implicitWidth * root.lineProgress : base.implicitWidth
        clip: true
        Behavior on width { NumberAnimation { duration: 100 } }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: base.text
          color: root.status === "synced" ? root.lineColor : (root.bar ? root.bar.barForeground : "#cdd6f4")
          font: base.font
        }
      }
    }

    // Slide each new line in from below.
    SequentialAnimation {
      id: lineIn
      NumberAnimation { target: line; property: "opacity"; to: 0; duration: 0 }
      ParallelAnimation {
        NumberAnimation { target: line; property: "opacity"; to: 1; duration: 220 }
        NumberAnimation { target: line; property: "y"; from: 6; to: 0; duration: 220; easing.type: Easing.OutCubic }
      }
    }
  }

  onLineTextChanged: lineIn.restart()

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: if (root.bar && root.bar.showTooltip) root.bar.showTooltip(root, root.title + (root.artist ? " — " + root.artist : ""))
    onExited: if (root.bar && root.bar.hideTooltip) root.bar.hideTooltip(root)
  }
}
