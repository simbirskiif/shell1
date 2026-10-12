import QtQuick
import "../../singletons"

// Внутренняя панель Bluetooth в стиле macOS: слева значок устройства
// (наушники, телефон, геймпад, клавиатура...), подключённое обведено
// кольцом, клик по строке подключает/отключает устройство.
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
            title: "Bluetooth"
            checked: MockState.bluetoothEnabled
            onBackRequested: root.backRequested()
            onToggled: MockState.toggleBluetooth()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        PanelList {
            width: parent.width
            model: MockState.bluetoothDevices

            delegate: Rectangle {
                id: rowItem

                required property string name
                required property string icon
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
                    onClicked: MockState.toggleDevice(rowItem.index)
                }

                PanelIcon {
                    id: iconSlot
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    icon: rowItem.icon
                    connected: rowItem.connected
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
            }
        }
    }
}
