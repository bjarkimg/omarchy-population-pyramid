import QtQuick
import qs.Commons
import qs.Ui

// Own MouseArea (not Button.hovered / HoverHandler) so preview works inside
// a directory Flickable. Clicks still lock/unlock via lockToggled.
Item {
  id: root

  property string countryCode: ""
  property string countryLabel: ""
  property bool locked: false
  property bool current: false
  property int fontSize: Style.font.body
  property bool bordered: true
  property real horizontalPadding: Style.spacing.controlPaddingX

  signal previewRequested(string code)
  signal lockToggled(string code)
  signal wheelScrolled(var wheel)

  Button {
    anchors.fill: parent
    text: root.countryLabel
    leftAlign: true
    bordered: root.bordered
    fontSize: root.fontSize
    horizontalPadding: root.horizontalPadding
    selected: root.locked && root.current
    active: !root.locked && root.current
    hasCursor: flagMouse.containsMouse
  }

  Text {
    visible: root.locked && root.current
    anchors.right: parent.right
    anchors.rightMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: "🔒"
    font.pixelSize: 8
  }

  MouseArea {
    id: flagMouse
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.previewRequested(root.countryCode)
    onPositionChanged: {
      if (containsMouse)
        root.previewRequested(root.countryCode)
    }
    onClicked: root.lockToggled(root.countryCode)
    onWheel: function(wheel) {
      root.wheelScrolled(wheel)
    }
  }
}
