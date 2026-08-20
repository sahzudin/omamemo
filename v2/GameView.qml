import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property var bar: null
  readonly property Item focusTarget: keyCatcher
  readonly property real contentImplicitHeight: contentColumn.implicitHeight
  readonly property string stateDirectory: {
    var configured = Quickshell.env("XDG_STATE_HOME")
    var base = configured && configured.length > 0
      ? configured
      : Quickshell.env("HOME") + "/.local/state"
    return base + "/omamemo"
  }
  readonly property string bestPath: stateDirectory + "/best.json"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent || foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color surface: Color.popups.background
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
  readonly property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  readonly property color cardFill: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property int firstIndex: -1
  property int moves: 0
  property int elapsed: 0
  property int matches: 0
  property int bestSeconds: 0
  property int selectedIndex: 0
  property bool busy: false
  property bool started: false
  property bool complete: matches === 8
  property bool directoryReady: false
  property bool pendingBestSave: false

  signal closeRequested()
  signal tabRequested(int direction)

  function padded(value) {
    return value < 10 ? "0" + value : String(value)
  }

  function timeTextFor(value) {
    return padded(Math.floor(value / 60)) + ":" + padded(value % 60)
  }

  function timeText() {
    return timeTextFor(elapsed)
  }

  function bestText() {
    return bestSeconds > 0 ? timeTextFor(bestSeconds) : "--:--"
  }

  function applyBest(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      var value = Number(parsed.bestSeconds)
      bestSeconds = isFinite(value) && value > 0 ? Math.floor(value) : 0
    } catch (error) {
      bestSeconds = 0
    }
  }

  function saveBest() {
    if (bestSeconds > 0 && elapsed >= bestSeconds) return
    bestSeconds = elapsed
    if (!directoryReady) {
      pendingBestSave = true
      return
    }
    pendingBestSave = false
    bestFile.setText(JSON.stringify({ bestSeconds: bestSeconds }))
  }

  function panelOpened() {
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function shuffledPairs() {
    var values = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7]
    for (var i = values.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1))
      var swap = values[i]
      values[i] = values[j]
      values[j] = swap
    }
    return values
  }

  function symbolFor(pairId) {
    return ["▲", ">_", "▦", "◉", "✦", "⌁", "◇", "⌂"][pairId]
  }

  function labelFor(pairId) {
    return ["ARCH", "TERMINAL", "TILING", "ORBIT", "SPARK", "WAVE", "VECTOR", "HOME"][pairId]
  }

  function newGame() {
    mismatchTimer.stop()
    elapsedTimer.stop()
    deck.clear()
    firstIndex = -1
    moves = 0
    elapsed = 0
    matches = 0
    selectedIndex = 0
    busy = false
    started = false

    var pairs = shuffledPairs()
    for (var i = 0; i < pairs.length; i++) {
      deck.append({
        pairId: pairs[i],
        symbol: symbolFor(pairs[i]),
        label: labelFor(pairs[i]),
        flipped: false,
        matched: false
      })
    }
  }

  function choose(index) {
    if (busy || index < 0 || index >= deck.count) return
    var card = deck.get(index)
    if (card.flipped || card.matched) return

    if (!started) {
      started = true
      elapsedTimer.start()
    }

    deck.setProperty(index, "flipped", true)

    if (firstIndex < 0) {
      firstIndex = index
      return
    }

    moves++
    if (deck.get(firstIndex).pairId === card.pairId) {
      deck.setProperty(firstIndex, "matched", true)
      deck.setProperty(index, "matched", true)
      firstIndex = -1
      matches++
      if (matches === 8) {
        elapsedTimer.stop()
        saveBest()
      }
    } else {
      busy = true
      mismatchTimer.first = firstIndex
      mismatchTimer.second = index
      firstIndex = -1
      mismatchTimer.restart()
    }
  }

  function moveSelection(dx, dy) {
    if (deck.count === 0) return
    var row = Math.floor(selectedIndex / 4)
    var column = selectedIndex % 4
    row = (row + dy + 4) % 4
    column = (column + dx + 4) % 4
    selectedIndex = row * 4 + column
  }

  Component.onCompleted: {
    newGame()
    ensureDirectory.running = true
  }

  ListModel { id: deck }

  Process {
    id: ensureDirectory
    command: ["mkdir", "-p", root.stateDirectory]
    onExited: function(exitCode) {
      root.directoryReady = exitCode === 0
      if (!root.directoryReady) return
      bestFile.reload()
      if (root.pendingBestSave) root.saveBest()
    }
  }

  FileView {
    id: bestFile
    path: root.bestPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyBest(text())
    onLoadFailed: root.applyBest("")
    onFileChanged: reload()
  }

  Timer {
    id: elapsedTimer
    interval: 1000
    repeat: true
    onTriggered: root.elapsed++
  }

  Timer {
    id: mismatchTimer
    interval: 680
    repeat: false
    property int first: -1
    property int second: -1
    onTriggered: {
      if (first >= 0 && first < deck.count) deck.setProperty(first, "flipped", false)
      if (second >= 0 && second < deck.count) deck.setProperty(second, "flipped", false)
      root.busy = false
      first = -1
      second = -1
    }
  }

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    onMoveRequested: function(dx, dy) { root.moveSelection(dx, dy) }
    onActivateRequested: root.choose(root.selectedIndex)
    onCloseRequested: root.closeRequested()
    onTabRequested: function(direction) { root.tabRequested(direction) }
    onTextKey: function(text) {
      if (text === "n" || text === "N" || text === "r" || text === "R") root.newGame()
    }

    Column {
      id: contentColumn
      width: parent.width
      spacing: Style.space(16)

      Item {
        width: parent.width
        implicitHeight: Style.space(56)

        Rectangle {
          id: heroMark
          width: Style.space(38)
          height: width
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          color: "transparent"
          border.color: root.accent
          border.width: Math.max(1, Style.space(1))
          radius: Style.cornerRadius

          Text {
            anchors.centerIn: parent
            text: "M"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
        }

        Column {
          anchors.left: heroMark.right
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Text {
            text: "OMAMEMO"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            font.letterSpacing: 1.1
          }

          Text {
            text: root.complete ? "MEMORY SYNCED" : "MATCH THE SYSTEM"
            color: root.complete ? root.accent : root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.2
          }
        }

        Rectangle {
          id: newButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(92)
          height: Style.space(30)
          radius: Style.cornerRadius
          color: newMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : root.cardFill
          border.color: newMouse.containsMouse ? root.accent : root.faint
          border.width: Math.max(1, Style.space(1))

          Text {
            anchors.centerIn: parent
            text: "↻  NEW GAME"
            color: newMouse.containsMouse ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.7
          }

          MouseArea {
            id: newMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.newGame()
          }
        }
      }

      Row {
        width: parent.width
        height: Style.space(34)
        spacing: Style.space(8)

        Repeater {
          model: [
            { key: "MOVES", value: root.padded(root.moves) },
            { key: "TIME", value: root.timeText() },
            { key: "PAIRS", value: root.matches + " / 8" },
            { key: "BEST", value: root.bestText() }
          ]

          Rectangle {
            required property var modelData
            width: (contentColumn.width - Style.space(24)) / 4
            height: Style.space(34)
            color: root.cardFill
            border.color: root.faint
            border.width: Math.max(1, Style.space(1))
            radius: Style.cornerRadius

            Row {
              anchors.centerIn: parent
              spacing: Style.space(7)

              Text {
                text: modelData.key
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.8
              }

              Text {
                text: modelData.value
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }
          }
        }
      }

      Item {
        id: boardHolder
        width: parent.width
        height: board.height

        readonly property real gap: Style.space(8)
        readonly property real cardSize: Math.floor((width - gap * 3) / 4)

        Grid {
          id: board
          anchors.horizontalCenter: parent.horizontalCenter
          columns: 4
          spacing: boardHolder.gap

          Repeater {
            model: deck

            Rectangle {
              id: card
              required property int index
              required property int pairId
              required property string symbol
              required property string label
              required property bool flipped
              required property bool matched

              readonly property bool revealed: flipped || matched
              readonly property bool selected: root.selectedIndex === index

              width: boardHolder.cardSize
              height: width
              radius: Style.cornerRadius
              color: revealed
                ? (matched ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                           : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10))
                : (cardMouse.containsMouse || selected ? Style.hoverFillFor(root.foreground, root.accent) : root.cardFill)
              border.color: revealed || selected || cardMouse.containsMouse ? root.accent : root.faint
              border.width: selected ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))
              scale: revealed ? 1.0 : 0.975

              Behavior on color { ColorAnimation { duration: 140 } }
              Behavior on border.color { ColorAnimation { duration: 120 } }
              Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

              Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Style.space(7)
                text: card.revealed ? card.label : root.padded(card.index + 1)
                color: card.revealed ? root.muted : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
                font.family: root.fontFamily
                font.pixelSize: Math.max(7, Style.font.caption - 1)
                font.letterSpacing: 0.6
              }

              Text {
                anchors.centerIn: parent
                text: card.revealed ? card.symbol : "M"
                color: card.revealed ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22)
                font.family: root.fontFamily
                font.pixelSize: card.revealed ? Style.font.display : Style.font.title
                font.bold: true
                opacity: root.busy && !card.revealed ? 0.65 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }
              }

              Rectangle {
                width: Style.space(4)
                height: width
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(7)
                color: card.matched ? root.accent : root.faint
              }

              MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: card.matched || root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
                onEntered: root.selectedIndex = card.index
                onClicked: root.choose(card.index)
              }
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          visible: root.complete
          z: 2
          color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.94)
          border.color: root.accent
          border.width: Math.max(1, Style.space(1))
          radius: Style.cornerRadius

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "✦"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "MEMORY SYNCED"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.5
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.moves + " moves  ·  " + root.timeText()
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Press N to play again"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.newGame()
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "ARROWS / HJKL TO MOVE   ·   ENTER TO FLIP   ·   N TO RESET"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Math.max(7, Style.font.caption - 1)
        font.letterSpacing: 0.65
      }
    }
  }
}
