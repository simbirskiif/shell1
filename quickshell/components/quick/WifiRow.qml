import QtQuick
import ".."
import "../../singletons"

// Строка сети Wi-Fi: значок сети слева, справа — состояние:
// индикатор подключения, «!» если нужны доп. действия (сертификат и т.п.)
// или замок для сети с паролем.
Rectangle {
    id: root

    required property string name
    required property int strength
    required property string security
    required property bool saved
    required property bool connected
    required property bool connecting

    signal activated()

    readonly property bool needsExtra: root.security === "enterprise"
    readonly property bool needsPassword: root.security === "psk"

    width: ListView.view ? ListView.view.width : implicitWidth
    height: Theme.quickRowHeight
    color: rowHover.hovered && !root.connecting ? Theme.quickTileHover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.connecting
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    PanelIcon {
        id: iconSlot
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: "\uf1eb"
        connected: root.connected
        strength: root.strength
    }

    Text {
        anchors.left: iconSlot.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.name
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    LoadingIndicator {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        visible: root.connecting
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.connecting && root.needsExtra
        text: "\uf06a"
        color: Theme.mediumColor
        font.family: Theme.iconFontFamily
        font.pixelSize: 13
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.connecting && !root.needsExtra && root.needsPassword
        text: "\uf023"
        color: Theme.quickTextDim
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
    }
}
