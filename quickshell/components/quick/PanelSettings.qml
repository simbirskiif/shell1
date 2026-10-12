import QtQuick
import ".."
import "../../singletons"

// Настройки оболочки: процент батареи в баре и порядок элементов бара.
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
            title: "Settings"
            checked: false
            switchable: false
            onBackRequested: root.backRequested()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        PanelSection { text: "Bar" }

        Item {
            width: parent.width
            height: 52

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: toggle.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Battery percentage"
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    text: "Show charge level next to the icon"
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            ToggleSwitch {
                id: toggle
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                checked: MockState.showBatteryPercent
                onToggled: MockState.showBatteryPercent = !MockState.showBatteryPercent
            }
        }

        PanelSection { text: "Bar order" }

        // Порядок слева-направо = порядок в модели; стрелки двигают элемент.
        PanelList {
            width: parent.width
            rowHeight: 48
            model: MockState.barItems

            delegate: Item {
                id: orderRow

                required property string itemKey
                required property string title
                required property int index

                width: ListView.view ? ListView.view.width : implicitWidth
                height: 48

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: orderRow.title
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        id: upButton

                        readonly property bool available: orderRow.index > 0

                        width: 30
                        height: 30
                        radius: width / 2
                        color: upHover.hovered && available ? Theme.quickTileHover : "transparent"
                        opacity: available ? 1 : 0.3
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf077"
                            color: Theme.quickText
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: upHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: upButton.available
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MockState.moveBarItem(orderRow.index, -1)
                        }
                    }

                    Rectangle {
                        id: downButton

                        readonly property bool available: orderRow.index < MockState.barItems.count - 1

                        width: 30
                        height: 30
                        radius: width / 2
                        color: downHover.hovered && available ? Theme.quickTileHover : "transparent"
                        opacity: available ? 1 : 0.3
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf078"
                            color: Theme.quickText
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: downHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: downButton.available
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MockState.moveBarItem(orderRow.index, 1)
                        }
                    }
                }
            }
        }
    }
}
