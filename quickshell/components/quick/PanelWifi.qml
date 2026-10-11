import QtQuick
import "../../singletons"

// Внутренняя панель Wi-Fi в стиле macOS: список сетей с уровнем
// сигнала, замком и отметкой подключённой сети.
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

                Item {
                    id: checkSlot
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14

                    Text {
                        anchors.centerIn: parent
                        visible: rowItem.connected
                        text: "\uf00c"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.left: checkSlot.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.name
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: rowItem.connected
                        text: "Connected"
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    SignalBars {
                        anchors.verticalCenter: parent.verticalCenter
                        strength: rowItem.strength
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: rowItem.secured
                        text: "\uf023"
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
