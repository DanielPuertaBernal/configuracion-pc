import QtQuick
import Quickshell
import Quickshell.Io

// Rotates through small chase animations drawn across a strip of the bar.
// Each animation lives in scenes/<Name>.qml.
Item {
  id: root

  // ---- Configuration -------------------------------------------------------
  // How long each animation plays before switching to the next one.
  readonly property int rotationIntervalMs: 5 * 60 * 1000
  // Animations to rotate through, in order. Remove a name to disable it.
  // Available: "ClaudeBug", "PacMan", "CatMouse", "Rocket", "Dino"
  readonly property var enabledScenes: ["ClaudeBug", "PacMan", "CatMouse", "Rocket", "Dino"]
  // --------------------------------------------------------------------------

  property var bar
  property string moduleName
  property var settings

  readonly property int trackWidth: settings && settings.width ? settings.width : 220
  property int sceneIndex: 0
  readonly property string sceneName: enabledScenes.length > 0
    ? enabledScenes[sceneIndex % enabledScenes.length] : ""

  implicitWidth: trackWidth
  implicitHeight: bar ? bar.barSize : 26

  // While pinned the current scene stays put until released.
  property bool pinned: false

  Timer {
    id: rotationTimer
    interval: root.rotationIntervalMs
    repeat: true
    onTriggered: root.sceneIndex = (root.sceneIndex + 1) % root.enabledScenes.length
  }

  // Terminal control: `nextgif [next|previous|--fijo|--libre]` writes
  // "<cmd> <epoch-ms>" to the command file below; it is polled because bar
  // widgets get no IPC target. Commands written before this widget started
  // are ignored.
  function step(delta) {
    const n = root.enabledScenes.length
    root.sceneIndex = (root.sceneIndex + delta + n) % n
    syncRotation()
    saveState()
  }

  function setPinned(value) {
    root.pinned = value
    syncRotation()
    saveState()
  }

  // Restarts the countdown, or keeps it stopped while pinned. Set imperatively
  // because Timer.restart() would override a `running` binding.
  function syncRotation() {
    rotationTimer.stop()
    if (!root.pinned && root.enabledScenes.length > 1) rotationTimer.start()
  }

  // Pin state survives shell restarts as "pinned <scene>" or "free".
  function saveState() {
    stateFile.setText(root.pinned ? "pinned " + root.sceneName + "\n" : "free\n")
  }

  readonly property real startedAt: Date.now()
  property real lastStamp: 0

  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.cache/danso-bugchase/state"
    blockLoading: true
    printErrors: false
  }

  Component.onCompleted: {
    const parts = stateFile.text().trim().split(/\s+/)
    if (parts[0] === "pinned") {
      const index = root.enabledScenes.indexOf(parts[1])
      if (index >= 0) root.sceneIndex = index
      root.pinned = true
    }
    syncRotation()
  }

  FileView {
    id: commandFile
    path: Quickshell.env("HOME") + "/.cache/danso-bugchase/cmd"
    printErrors: false
    onLoaded: {
      const parts = text().trim().split(/\s+/)
      const stamp = Number(parts[1])
      const fresh = stamp > root.startedAt && stamp < Date.now() + 60000
      if (!fresh || stamp === root.lastStamp) return
      root.lastStamp = stamp
      if (parts[0] === "next") root.step(1)
      else if (parts[0] === "previous") root.step(-1)
      else if (parts[0] === "pin") root.setPinned(true)
      else if (parts[0] === "unpin") root.setPinned(false)
    }
  }

  Timer {
    interval: 400
    repeat: true
    running: true
    onTriggered: commandFile.reload()
  }

  Loader {
    id: sceneLoader
    anchors.fill: parent
    source: root.sceneName ? Qt.resolvedUrl("scenes/" + root.sceneName + ".qml") : ""
    onLoaded: {
      item.bar = Qt.binding(() => root.bar)
      item.trackWidth = Qt.binding(() => root.trackWidth)
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: if (root.bar && root.bar.showTooltip && sceneLoader.item)
      root.bar.showTooltip(root, sceneLoader.item.tooltip)
    onExited: if (root.bar && root.bar.hideTooltip) root.bar.hideTooltip(root)
  }
}
