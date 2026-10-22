import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  // Mirror the bars so the left instance grows toward the clock.
  readonly property bool mirror: settings && settings.mirror === true
  readonly property int barCount: 10
  readonly property int barWidth: 3
  readonly property int barGap: 2
  // Catppuccin Mocha palette so each bar stands out from the bar background.
  readonly property var barColors: ["#cba6f7", "#f5c2e7", "#f38ba8", "#fab387", "#f9e2af",
                                  "#a6e3a1", "#94e2d5", "#89dceb", "#74c7ec", "#89b4fa"]
  property var levels: []
  property bool cavaSilent: true
  // Spotify reports "Playing" over MPRIS even when the audio goes to another
  // device (Spotify Connect). In that case there is no local audio for cava,
  // so the bars fall back to a simulated beat.
  readonly property bool spotifyPlaying: {
    const list = Mpris.players ? Mpris.players.values : []
    for (let i = 0; i < list.length; i++) {
      const p = list[i]
      const name = String(p.identity || p.desktopEntry || "").toLowerCase()
      if (name.indexOf("spotify") !== -1 && p.isPlaying) return true
    }
    return false
  }
  readonly property bool simulating: cavaSilent && spotifyPlaying
  readonly property bool idle: cavaSilent && !spotifyPlaying

  implicitWidth: barCount * barWidth + (barCount - 1) * barGap + 8
  implicitHeight: bar ? bar.barSize : 26

  Process {
    id: cava
    running: true
    command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function(line) {
        const values = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
        root.cavaSilent = values.every(v => v === 0)
        if (root.cavaSilent && root.spotifyPlaying) return
        root.levels = root.mirror ? values.reverse() : values
      }
    }
    onExited: restartTimer.start()
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
      const phase = (root.simTime % beat) / beat
      const kick = Math.exp(-phase * 6)
      const offPhase = ((root.simTime + beat / 2) % beat) / beat
      const snare = Math.exp(-offPhase * 8) * 0.6
      const next = []
      for (let i = 0; i < root.barCount; i++) {
        const pos = i / (root.barCount - 1)
        const low = (1 - pos) * kick
        const mid = Math.sin(pos * Math.PI) * snare
        const high = pos * (0.25 + Math.random() * 0.45)
        const target = Math.min(1, 0.08 + low * 0.85 + mid + high * 0.6)
        const prev = root.simState.length > i ? root.simState[i] : 0
        next.push(prev + (target - prev) * 0.45)
      }
      root.simState = next
      root.levels = root.mirror ? next.slice().reverse() : next
    }
  }

  Timer {
    id: restartTimer
    interval: 3000
    onTriggered: cava.running = true
  }

  Row {
    anchors.centerIn: parent
    spacing: root.barGap
    opacity: root.idle ? 0.35 : 1

    Behavior on opacity { NumberAnimation { duration: 300 } }

    Repeater {
      model: root.barCount

      Rectangle {
        required property int index
        readonly property real level: root.levels.length > index ? root.levels[index] : 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.barWidth
        height: Math.max(2, level * (root.implicitHeight - 8))
        radius: width / 2
        color: root.barColors[root.mirror ? root.barCount - 1 - index : index]

        Behavior on height { NumberAnimation { duration: 60 } }
      }
    }
  }
}
