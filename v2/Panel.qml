import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.sahzudin.omamemo"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  function newGame() {
    if (game) game.newGame()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  onOpenedChanged: {
    if (opened && game) game.panelOpened()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: game.focusTarget
    contentWidth: panel.fittedContentWidth(Style.space(438))
    contentHeight: panel.fittedContentHeight(game.contentImplicitHeight, Style.space(610))

    GameView {
      id: game
      anchors.fill: parent
      bar: root.bar
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }
  }
}
