import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "danso.spotify"

  readonly property var player: {
    const list = Mpris.players ? Mpris.players.values : []
    for (let i = 0; i < list.length; i++) {
      const p = list[i]
      const name = String(p.identity || p.desktopEntry || "").toLowerCase()
      if (name.indexOf("spotify") !== -1) return p
    }
    return null
  }

  // Spotify's own PipeWire playback stream, so volume changes affect only Spotify.
  readonly property var streams: {
    const nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    const found = []
    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (!n || !n.isStream) continue
      const props = n.properties || {}
      const label = String(props["application.name"] || "") + " "
        + String(props["application.process.binary"] || "") + " " + String(n.name || "")
      if (label.toLowerCase().indexOf("spotify") !== -1 && n.audio) found.push(n)
    }
    return found
  }
  readonly property var stream: streams.length > 0 ? streams[0] : null
  readonly property real volume: stream && stream.audio ? stream.audio.volume : 0

  readonly property bool isPlaying: player ? player.isPlaying : false
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""

  property bool popupOpen: false

  // Catppuccin Mocha palette, shared with the danso.visualizer bar widget.
  readonly property var barColors: ["#cba6f7", "#f5c2e7", "#f38ba8", "#fab387", "#f9e2af",
                                    "#a6e3a1", "#94e2d5", "#89dceb", "#74c7ec", "#89b4fa"]
  readonly property int vizBarCount: 24
  property var levels: []

  property bool cavaSilent: true
  // Spotify Connect: "Playing" with no local audio, so fall back to a simulated beat.
  readonly property bool simulating: popupOpen && isPlaying && cavaSilent

  // Only analyse audio while the popup is visible.
  Process {
    id: cava
    running: root.popupOpen
    command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function(line) {
        const values = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
        root.cavaSilent = values.every(v => v === 0)
        if (root.cavaSilent && root.isPlaying) return
        root.levels = values
      }
    }
    onRunningChanged: if (!running) { root.levels = []; root.cavaSilent = true }
  }

  // Simulated spectrum: a 120 BPM kick drives the low bars, a softer
  // off-beat drives the mids, and the highs get smoothed jitter.
  property real simTime: 0
  property var simState: []
  Timer {
    interval: 33
    repeat: true
    running: root.simulating
    onRunningChanged: if (!running) root.simState = []
    onTriggered: {
      root.simTime += interval / 1000
      const beat = 0.5
      const kick = Math.exp(-((root.simTime % beat) / beat) * 6)
      const snare = Math.exp(-(((root.simTime + beat / 2) % beat) / beat) * 8) * 0.6
      const next = []
      for (let i = 0; i < root.vizBarCount; i++) {
        const pos = i / (root.vizBarCount - 1)
        const low = (1 - pos) * kick
        const mid = Math.sin(pos * Math.PI) * snare
        const high = pos * (0.25 + Math.random() * 0.45)
        const target = Math.min(1, 0.08 + low * 0.85 + mid + high * 0.6)
        const prev = root.simState.length > i ? root.simState[i] : 0
        next.push(prev + (target - prev) * 0.45)
      }
      root.simState = next
      root.levels = next
    }
  }
  function close() { popupOpen = false }

  // `qs -p /usr/share/omarchy/shell/shell.qml ipc call danso.spotify toggle`
  IpcHandler {
    target: "danso.spotify"
    function toggle(): void { root.popupOpen = !root.popupOpen }
    function open(): void { root.popupOpen = true }
    function close(): void { root.popupOpen = false }
  }

  // Free-text search: search.py lists matches (title, artist, cover) and, once one is
  // picked, resolves that exact track on Spotify and plays it.
  readonly property string searchHelper: Qt.resolvedUrl("search.py").toString().replace("file://", "")
  property string searchStatus: ""
  property var searchResults: []
  property int selectedResult: -1

  Process {
    id: searchProc
    stdout: StdioCollector {
      onStreamFinished: {
        let rows = []
        try { rows = JSON.parse(text) } catch (e) { rows = [] }
        root.searchResults = Array.isArray(rows) ? rows : []
        root.selectedResult = root.searchResults.length > 0 ? 0 : -1
        root.searchStatus = root.searchResults.length > 0 ? "" : "No matches"
      }
    }
    onExited: function(code) { if (code !== 0) root.searchStatus = "Search failed" }
  }

  Process {
    id: playProc
    stdout: StdioCollector {
      onStreamFinished: root.searchStatus = text.trim() === "search" ? "Opened in Spotify search" : ""
    }
    onExited: function(code) { if (code !== 0) root.searchStatus = "Could not play that track" }
  }

  function runSearch(query) {
    const q = String(query || "").trim()
    if (q === "" || searchProc.running) return
    clearResults()
    searchStatus = "Searching…"
    searchProc.command = ["python3", "-I", searchHelper, "search", q]
    searchProc.running = true
  }

  function playResult(index) {
    const item = searchResults[index]
    if (!item || playProc.running) return
    searchStatus = "Opening " + item.title + " — " + item.artist + "…"
    playProc.command = ["python3", "-I", searchHelper, "play", item.id || "", item.title, item.artist]
    playProc.running = true
    clearResults()
    searchField.text = ""
  }

  function clearResults() {
    searchResults = []
    selectedResult = -1
  }

  function moveSelection(step) {
    if (searchResults.length === 0) return
    selectedResult = (selectedResult + step + searchResults.length) % searchResults.length
  }


  readonly property bool canSeek: player ? (player.canSeek && player.positionSupported && player.lengthSupported) : false
  readonly property real length: player ? player.length : 0

  // MPRIS position is not pushed by the player; poll it while the popup is visible.
  Timer {
    interval: 1000
    repeat: true
    running: root.popupOpen && root.isPlaying
    onTriggered: if (root.player) root.player.positionChanged()
  }

  function seekBy(seconds) {
    if (!canSeek) return
    player.position = Math.max(0, Math.min(length, player.position + seconds))
  }

  function formatTime(seconds) {
    const s = Math.max(0, Math.floor(seconds || 0))
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
  }

  // Volume the user picked. Spotify opens each track at its own level, so this is reapplied
  // on every track change no matter where the change came from. -1 means "not chosen yet".
  // Persisted so it survives shell restarts.
  property real desiredVolume: -1

  FileView {
    id: volumeFile
    path: Quickshell.env("HOME") + "/.local/state/danso.spotify/volume"
    printErrors: false
    onLoaded: {
      const v = Number(text().trim())
      if (isFinite(v) && v >= 0 && v <= 1) {
        root.desiredVolume = v
        reapplyVolume.restart()
      }
    }
  }

  function applyVolume(v) {
    for (let i = 0; i < streams.length; i++) {
      if (streams[i].audio && Math.abs(streams[i].audio.volume - v) > 0.001) streams[i].audio.volume = v
    }
  }

  function rememberVolume(v) {
    if (Math.abs(desiredVolume - v) < 0.001) return
    desiredVolume = v
    volumeFile.setText(v.toFixed(3) + "\n")
  }

  function setVolume(v) {
    rememberVolume(v)
    applyVolume(v)
  }

  function handleTrackChange() {
    adoptVolume.stop()
    if (desiredVolume >= 0) reapplyVolume.restart()
  }
  onStreamsChanged: handleTrackChange()
  onTitleChanged: handleTrackChange()

  // A volume change that is not followed by a track change came from the user
  // (e.g. Spotify's own slider), so adopt it after a short settle delay.
  // Changes around a track change are Spotify resetting the level and are ignored.
  onVolumeChanged: if (stream && !reapplyVolume.running) adoptVolume.restart()

  Timer {
    id: adoptVolume
    interval: 1500
    onTriggered: if (root.stream && !reapplyVolume.running) root.rememberVolume(root.volume)
  }

  // Stream audio properties bind asynchronously and Spotify may reset the level a moment
  // after the track starts, so keep enforcing it for a few seconds.
  Timer {
    id: reapplyVolume
    interval: 200
    repeat: true
    property int attempts: 0
    onRunningChanged: if (running) attempts = 0
    onTriggered: {
      if (root.desiredVolume >= 0) root.applyVolume(root.desiredVolume)
      if (++attempts >= 20) stop()
    }
  }

  visible: player !== null
  implicitWidth: player ? icon.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  PwObjectTracker { objects: root.streams }

  Text {
    id: icon
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: ""
    color: root.isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.body
    Behavior on color { ColorAnimation { duration: 160 } }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) { if (root.player) root.player.togglePlaying() }
      else root.popupOpen = !root.popupOpen
    }
    onWheel: function(wheel) {
      const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
      root.setVolume(Math.max(0, Math.min(1, root.volume + step)))
    }
    onEntered: if (root.bar && root.title) root.bar.showTooltip(root, root.title + (root.artist ? " — " + root.artist : ""))
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // KeyboardPanel (layer-shell) rather than PopupCard (xdg-popup): xdg-popups only get
  // keys after a click routes focus through them, which left the search field deaf.
  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: searchField
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      TextField {
        id: searchField
        width: parent.width
        foreground: root.bar.foreground
        placeholderText: "Search a song and press Enter"
        onTextEdited: { root.clearResults(); root.searchStatus = "" }
        onAccepted: {
          if (root.selectedResult >= 0) root.playResult(root.selectedResult)
          else root.runSearch(text)
        }
        Keys.onUpPressed: root.moveSelection(-1)
        Keys.onDownPressed: root.moveSelection(1)
        Keys.onEscapePressed: function(event) {
          if (root.searchResults.length > 0) root.clearResults()
          else if (text !== "") text = ""
          else { event.accepted = false; return }
          event.accepted = true
        }
      }

      Text {
        width: parent.width
        visible: root.searchStatus !== ""
        textFormat: Text.PlainText
        text: root.searchStatus
        color: Qt.darker(root.bar.foreground, 1.3)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      Column {
        width: parent.width
        spacing: Style.space(2)
        visible: root.searchResults.length > 0

        Repeater {
          model: root.searchResults

          Rectangle {
            required property var modelData
            required property int index
            readonly property bool selected: index === root.selectedResult
            width: parent.width
            height: Style.space(36)
            radius: Style.cornerRadius
            color: selected ? Style.normalFillFor(root.bar.foreground, Color.accent) : "transparent"
            border.width: selected ? 1 : 0
            border.color: Color.accent

            Image {
              id: cover
              anchors.left: parent.left
              anchors.leftMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(32)
              height: Style.space(32)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              source: modelData.cover || ""
            }

            Column {
              anchors.left: cover.right
              anchors.leftMargin: Style.space(8)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: modelData.title
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: modelData.artist
                color: Color.accent
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selectedResult = index
              onClicked: root.playResult(index)
            }
          }
        }
      }

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.player || !root.player.trackArtUrl
            text: ""
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            textFormat: Text.PlainText
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Item {
        id: viz
        width: parent.width
        height: Style.space(48)

        readonly property real gap: Style.space(3)
        readonly property real barWidth: (width - gap * (root.vizBarCount - 1)) / root.vizBarCount

        Row {
          anchors.bottom: parent.bottom
          spacing: viz.gap

          Repeater {
            model: root.vizBarCount

            Rectangle {
              required property int index
              readonly property real level: root.levels.length > index ? root.levels[index] : 0
              anchors.bottom: parent.bottom
              width: viz.barWidth
              height: Math.max(3, level * viz.height)
              radius: Math.min(width / 2, Style.space(3))
              color: root.barColors[Math.floor(index * root.barColors.length / root.vizBarCount)]
              opacity: root.isPlaying ? 1.0 : 0.35

              Behavior on height { NumberAnimation { duration: 60 } }
            }
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          id: posLabel
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.formatTime(root.player ? root.player.position : 0)
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          width: Style.space(36)
        }

        PanelSlider {
          bar: root.bar
          width: parent.width - posLabel.width - lenLabel.width - Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          minimum: 0
          maximum: Math.max(1, root.length)
          step: 1
          value: root.player ? root.player.position : 0
          enabled: root.canSeek
          opacity: enabled ? 1.0 : 0.4
          onMoved: function(v) { if (root.canSeek) root.player.position = v }
        }

        Text {
          id: lenLabel
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.formatTime(root.length)
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          width: Style.space(36)
          horizontalAlignment: Text.AlignRight
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "\uDB83\uDD2A"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.canSeek
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.seekBy(-10)
        }

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.player && root.player.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.player.previous()
        }

        Button {
          iconText: root.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.player && root.player.canTogglePlaying
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.player.togglePlaying()
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.player && root.player.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.player.next()
        }

        Button {
          iconText: "\uDB83\uDD71"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.canSeek
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.seekBy(10)
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          id: volIcon
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.volume <= 0.001 ? "󰝟" : (root.volume < 0.5 ? "󰖀" : "󰕾")
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          width: Style.space(18)
        }

        PanelSlider {
          bar: root.bar
          width: parent.width - volIcon.width - volLabel.width - Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          minimum: 0
          maximum: 1
          step: 0.05
          value: root.volume
          enabled: root.stream !== null
          opacity: enabled ? 1.0 : 0.4
          onMoved: function(v) { root.setVolume(v) }
        }

        Text {
          id: volLabel
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.stream ? Math.round(root.volume * 100) + "%" : "—"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          width: Style.space(36)
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }
}
