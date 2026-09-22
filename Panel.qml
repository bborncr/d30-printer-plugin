import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button + popup for the Phomemo D30 label maker. Type, glance at the
// live preview, hit Enter. Rendering and Bluetooth live in bin/d30-print.
Panel {
  id: root
  moduleName: "io.github.bborncr.d30-label"
  ipcTarget: "io.github.bborncr.d30-label"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.4)

  readonly property string scriptPath: Qt.resolvedUrl("bin/d30-print").toString().replace(/^file:\/\//, "")
  readonly property string runtimeDir: String(Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
  readonly property string previewPath: runtimeDir + "/omarchy-d30-preview.png"

  readonly property var sizes: [
    { value: "40x12", label: "40 × 12 mm" },
    { value: "30x12", label: "30 × 12 mm" },
    { value: "50x12", label: "50 × 12 mm" },
    { value: "22x12", label: "22 × 12 mm" }
  ]

  property string labelText: ""
  property string size: String(setting("defaultSize", "40x12"))
  property int copies: 1

  property bool printing: false
  property bool previewing: false
  property bool previewDirty: false
  property int previewSerial: 0
  property bool previewReady: false
  property string statusText: ""
  property bool statusIsError: false
  property string stderrText: ""

  readonly property real labelAspect: {
    var m = /^(\d+)x(\d+)$/.exec(size)
    return m ? Number(m[1]) / Number(m[2]) : 40 / 12
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onSettingsChanged: size = String(setting("defaultSize", "40x12"))

  onOpenedChanged: {
    if (opened) {
      if (labelText !== "") requestPreview()
    } else {
      if (!printing) { statusText = ""; statusIsError = false }
    }
  }

  onLabelTextChanged: {
    if (statusText !== "" && !printing) { statusText = ""; statusIsError = false }
    if (labelText.trim() === "") { previewReady = false; return }
    previewTimer.restart()
  }
  onSizeChanged: if (labelText.trim() !== "") requestPreview()

  function argsFor(cmd) {
    var args = [scriptPath, cmd, "--size", size]
    if (setting("flip", false) === true) args.push("--flip")
    var font = String(setting("font", "") || "")
    if (font !== "") args.push("--font", font)
    return args
  }

  function requestPreview() {
    if (previewProc.running) { previewDirty = true; return }
    previewDirty = false
    previewing = true
    previewProc.command = argsFor("preview").concat(["--scale", "3", "--out", previewPath, "--", labelText])
    previewProc.running = true
  }

  function printLabel() {
    if (printing) return
    if (labelText.trim() === "") {
      statusText = "Type something first"
      statusIsError = true
      return
    }
    printing = true
    statusIsError = false
    statusText = "Printing…"
    stderrText = ""
    var args = argsFor("print").concat(["--copies", String(copies)])
    var addr = String(setting("address", "") || "").trim()
    if (addr !== "") args.push("--address", addr)
    printProc.command = args.concat(["--", labelText])
    printProc.running = true
  }

  Timer {
    id: previewTimer
    interval: 180
    onTriggered: root.requestPreview()
  }

  Process {
    id: previewProc
    onExited: function(exitCode) {
      root.previewing = false
      if (exitCode === 0) {
        root.previewSerial++
        root.previewReady = true
      }
      if (root.previewDirty) Qt.callLater(root.requestPreview)
    }
  }

  Process {
    id: printProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.stderrText = String(text || "").trim()
        if (root.statusIsError && root.stderrText !== "") root.statusText = root.stderrText
      }
    }
    onExited: function(exitCode) {
      root.printing = false
      if (exitCode === 0) {
        root.statusIsError = false
        root.statusText = root.copies > 1 ? "Printed " + root.copies + " labels" : "Printed"
        doneTimer.restart()
      } else {
        root.statusIsError = true
        root.statusText = root.stderrText || "Printing failed"
      }
    }
  }

  Timer {
    id: doneTimer
    interval: 2500
    onTriggered: if (!root.statusIsError && !root.printing) root.statusText = ""
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "D30 label"
    iconComponent: Component {
      Item {
        Text {
          anchors.centerIn: parent
          text: "󰓹"
          font.family: root.fontFamily
          font.pixelSize: Style.space(14)
          color: root.printing ? (root.bar ? root.bar.urgent : Color.urgent) : root.barForeground
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: textField
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "D30 Label Printer"
          meta: root.statusText !== "" ? root.statusText
              : (root.previewing && !root.previewReady ? "Rendering…" : "Enter prints · Esc closes")
          foreground: root.statusIsError ? (root.bar ? root.bar.urgent : Color.urgent) : root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "󰓹"
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              color: root.foreground
            }
          }
        }

        // Label preview: white "paper" with the label's real aspect ratio.
        Rectangle {
          id: paper
          width: parent.width
          height: Math.round(width / root.labelAspect)
          radius: Style.space(6)
          color: "white"
          border.width: 1
          border.color: Qt.rgba(0, 0, 0, 0.25)
          clip: true

          Image {
            anchors.fill: parent
            anchors.margins: 1
            visible: root.previewReady && root.labelText.trim() !== ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: false
            asynchronous: true
            source: root.previewReady ? "file://" + root.previewPath + "?" + root.previewSerial : ""
          }

          Text {
            anchors.centerIn: parent
            visible: !(root.previewReady && root.labelText.trim() !== "")
            text: root.labelText.trim() === "" ? "Type to preview" : "…"
            color: "#888888"
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        TextField {
          id: textField
          width: parent.width
          placeholderText: "Label text  (\\n for a new line)"
          foreground: root.foreground
          text: root.labelText
          onTextChanged: root.labelText = text
          onAccepted: root.printLabel()
        }

        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          // Dropdown and NumberField draw their captions with different
          // fonts and gaps, so give the dropdown a caption that mirrors
          // NumberField's and the two controls land on the same baseline.
          Column {
            Layout.fillWidth: true
            spacing: Style.spacing.md

            Text {
              textFormat: Text.PlainText
              text: "Size"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Dropdown {
              width: parent.width
              showLabel: false
              options: root.sizes
              value: root.size
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(v) { root.size = v }
            }
          }

          NumberField {
            label: "Copies"
            value: root.copies
            from: 1
            to: 20
            foreground: root.foreground
            fontFamily: root.fontFamily
            fieldWidth: Style.space(64)
            onModified: function(v) { root.copies = v }
          }
        }

        Button {
          width: parent.width
          text: root.printing ? "Printing…" : (root.copies > 1 ? "Print " + root.copies + " labels" : "Print label")
          iconText: "󰐪"
          bordered: true
          enabled: !root.printing
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.printLabel()
        }
      }
    }
  }
}
