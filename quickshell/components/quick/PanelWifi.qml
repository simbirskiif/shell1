import QtQuick
import "../../singletons"

// Внутренняя панель Wi-Fi в стиле macOS: значок сети слева,
// подключённая сеть обведена кольцом, справа — замок у закрытых.
Item {
    id: root

    signal backRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: "Wi-Fi"
            checked: MockState.wifiEnabled
            onBackRequested: root.backRequested()
            onToggled: MockState.toggleWifi()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        PanelList {
            width: parent.width
            model: MockState.wifiNetworks

            delegate: Rectangle {
                id: rowItem

                required property string name
                required property int strength
                required property bool secured
                required property bool connected
                required property int index

                width: ListView.view ? ListView.view.width : implicitWidth
                height: Theme.quickRowHeight
                color: rowHover.hovered ? Theme.quickTileHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.quickHoverDuration } }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MockState.selectWifi(rowItem.index)
                }

                PanelIcon {
                    id: iconSlot
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\uf1eb"
                    connected: rowItem.connected
                    strength: rowItem.strength
                }

                Text {
                    anchors.left: iconSlot.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.name
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowItem.secured
                    text: "\uf023"
                    color: Theme.quickTextDim
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 12
                }
            }
        }
    }
}
