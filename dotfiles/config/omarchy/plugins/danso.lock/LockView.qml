import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// Stark-style HUD lock screen. Only the visuals differ from omarchy.lock:
// properties, signals, functions and the password TextInput behavior are kept
// identical so Service.qml (PAM flows) works unchanged.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string ownerName: "señor Daniel"
  readonly property string placeholderText: "Contraseña"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 58
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.0)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0

  // HUD palette: arc-reactor cyan, Stark gold, alert red.
  readonly property color hudCyan: "#5ce1ff"
  readonly property color hudGold: "#ffc857"
  readonly property color hudRed: "#ff4d5e"
  readonly property color hudText: "#e6f7ff"
  readonly property color hudDim: "#7fa9bf"
  readonly property color accent: errorState ? hudRed : (authenticatingPassword ? hudGold : hudCyan)
  readonly property real spinFactor: authenticatingPassword ? 4 : (errorState ? 2 : 1)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  property date now: new Date()
  Timer {
    interval: 1000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  Rectangle {
    anchors.fill: parent
    color: "#05080d"

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      brightness: -0.35
      saturation: -0.4
    }

    // Vignette + scanlines for the HUD look.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#cc02060c" }
        GradientStop { position: 0.5; color: "#5502060c" }
        GradientStop { position: 1.0; color: "#dd02060c" }
      }
    }
    Canvas {
      anchors.fill: parent
      opacity: 0.06
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = "#5ce1ff"
        for (var y = 0; y < height; y += 4) ctx.fillRect(0, y, width, 1)
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // Top-left: "Programmer coding" animation from LottieFiles (see CREDITS.txt).
    AnimatedImage {
      id: coder
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: 40
      width: 420
      height: 396
      source: Qt.resolvedUrl("coder.gif")
      fillMode: Image.PreserveAspectFit
      playing: root.visible
      smooth: true
      mipmap: true
    }

    // Top-right clock.
    Column {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 48
      spacing: 4
      Text {
        anchors.right: parent.right
        text: Qt.formatTime(root.now, "HH:mm")
        color: root.hudText
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 3.2)
        font.letterSpacing: 4
      }
      Text {
        anchors.right: parent.right
        text: root.now.toLocaleDateString(Qt.locale("es_CO"), "dddd d 'de' MMMM").toUpperCase()
        color: root.hudDim
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 0.75)
        font.letterSpacing: 2
      }
    }

    // Bottom-left system readout.
    Column {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.margins: 48
      spacing: 4
      Repeater {
        model: [
          "REACTOR ARC ........ 100%",
          "SISTEMAS ........... EN LÍNEA",
          "SESIÓN ............. BLOQUEADA",
          "INTENTOS FALLIDOS .. " + root.failedAttempts
        ]
        Text {
          required property string modelData
          text: modelData
          color: index === 3 && root.failedAttempts > 0 ? root.hudRed : root.hudDim
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 0.65)
          font.letterSpacing: 1
          required property int index
        }
      }
    }

    // Center: arc reactor + prompt + password field.
    Column {
      anchors.centerIn: parent
      spacing: 28

      Item {
        id: reactor
        width: 300
        height: 300
        anchors.horizontalCenter: parent.horizontalCenter

        // Outer dashed ring.
        Canvas {
          id: outerRing
          anchors.fill: parent
          property color ringColor: root.accent
          onRingColorChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = width / 2
            ctx.strokeStyle = ringColor
            ctx.lineWidth = 3
            for (var i = 0; i < 12; i++) {
              var start = i * Math.PI / 6
              ctx.beginPath()
              ctx.arc(c, c, c - 4, start, start + Math.PI / 9)
              ctx.stroke()
            }
          }
          RotationAnimation on rotation {
            from: 0; to: 360; loops: Animation.Infinite
            duration: 24000 / root.spinFactor
          }
        }

        // Tick ring, counter-rotating.
        Canvas {
          id: tickRing
          anchors.fill: parent
          anchors.margins: 26
          property color ringColor: root.accent
          onRingColorChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = width / 2
            ctx.strokeStyle = ringColor
            ctx.globalAlpha = 0.8
            for (var i = 0; i < 60; i++) {
              var a = i * Math.PI / 30
              var inner = c - (i % 5 === 0 ? 16 : 8)
              ctx.lineWidth = i % 5 === 0 ? 3 : 1
              ctx.beginPath()
              ctx.moveTo(c + Math.cos(a) * inner, c + Math.sin(a) * inner)
              ctx.lineTo(c + Math.cos(a) * (c - 2), c + Math.sin(a) * (c - 2))
              ctx.stroke()
            }
          }
          RotationAnimation on rotation {
            from: 360; to: 0; loops: Animation.Infinite
            duration: 16000 / root.spinFactor
          }
        }

        // Inner triangular core frame.
        Canvas {
          anchors.fill: parent
          anchors.margins: 78
          property color ringColor: root.accent
          onRingColorChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = width / 2
            ctx.strokeStyle = ringColor
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.arc(c, c, c - 2, 0, 2 * Math.PI)
            ctx.stroke()
            ctx.beginPath()
            for (var i = 0; i < 3; i++) {
              var a = -Math.PI / 2 + i * 2 * Math.PI / 3
              var x = c + Math.cos(a) * (c - 14)
              var y = c + Math.sin(a) * (c - 14)
              if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.closePath()
            ctx.stroke()
          }
        }

        // Glowing core.
        Rectangle {
          id: core
          width: 70
          height: 70
          radius: 35
          anchors.centerIn: parent
          color: root.accent
          SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 1400 / root.spinFactor; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.95; duration: 1400 / root.spinFactor; easing.type: Easing.InOutSine }
          }
        }
        MultiEffect {
          anchors.fill: core
          source: core
          blurEnabled: true
          blur: 1.0
          blurMax: 64
          brightness: 0.4
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.authenticatingPassword
          ? "Verificando identidad…"
          : (root.errorState ? "Acceso denegado, " + root.ownerName + "." : "Identificación requerida, " + root.ownerName + ".")
        color: root.errorState ? root.hudRed : root.hudText
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 0.95)
        font.letterSpacing: 2
      }

      Rectangle {
        id: inputField
        width: root.fieldWidth
        height: root.fieldHeight
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#b305101a"
        border.color: root.accent
        border.width: 2
        radius: 4
        clip: true

        // Corner brackets.
        Repeater {
          model: 4
          Item {
            required property int index
            width: 14; height: 14
            x: index % 2 === 0 ? -1 : inputField.width - 13
            y: index < 2 ? -1 : inputField.height - 13
            Rectangle { width: 14; height: 3; color: root.accent; y: index < 2 ? 0 : 11 }
            Rectangle { width: 3; height: 14; color: root.accent; x: index % 2 === 0 ? 0 : 11 }
          }
        }

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.rightMargin: 18 + root.fingerprintReserve
          anchors.leftMargin: 18 + root.fingerprintReserve
          verticalAlignment: TextInput.AlignVCenter
          horizontalAlignment: TextInput.AlignHCenter
          activeFocusOnPress: true
          clip: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          echoMode: TextInput.Password
          passwordCharacter: "●"
          passwordMaskDelay: 0
          color: root.hudCyan
          selectionColor: root.hudCyan
          selectedTextColor: "#05080d"
          font.family: Style.font.family
          font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
          font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
          cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
          cursorDelegate: Rectangle {
            width: 2
            color: root.hudCyan
            visible: passwordInput.cursorVisible
          }

          onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0) {
              root.wakeRequested()
            }
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.fill: passwordInput
          text: root.authenticatingPassword ? "Escaneando…" : (root.errorState ? root.failureMessage : root.placeholderText)
          visible: passwordInput.text.length === 0
          color: root.authenticatingPassword ? root.hudGold : (root.errorState ? root.hudRed : root.hudDim)
          font.family: Style.font.family
          font.pixelSize: root.fieldFontSize
          font.italic: !root.authenticatingPassword && root.errorState
          font.letterSpacing: 2
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        Text {
          id: fingerprintIcon
          objectName: "fingerprintIndicator"
          anchors.right: parent.right
          anchors.rightMargin: 18
          anchors.verticalCenter: parent.verticalCenter
          visible: root.fingerprintConfigured
          text: "󰈷"
          color: root.accent
          font.family: Style.font.family
          font.pixelSize: Math.round(root.fieldFontSize * 1.1)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }
}
