import QtQuick
import ".."
import "../../singletons"

// Панель питания: заряд, состояние и время, выбор режима питания.
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
            title: "Battery"
            checked: false
            switchable: false
            onBackRequested: root.backRequested()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        // Заряд: «батарейка» с уровнем, процент и время.
        Item {
            width: parent.width
            height: 150

            // Большая батарейка — тот же дизайн, что и в баре.
            BatteryIndicator {
                id: batteryArt
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 22
                level: MockState.batteryLevel
                charging: MockState.batteryCharging
                bodyWidth: 150
                bodyHeight: 58
                bodyRadius: 18
                nubWidth: 7
            }

            Text {
                id: percentText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: batteryArt.bottom
                anchors.topMargin: 14
                text: MockState.batteryLevel + "%"
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: percentText.bottom
                anchors.topMargin: 4
                text: MockState.batteryState + " · " + MockState.batteryTime
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        PanelSection { text: "Power mode" }

        // Режим питания: три сегмента, выбранный залит акцентом (m3 segmented).
        Item {
            width: parent.width
            height: 56

            readonly property real segmentWidth: (width - 32 - 12) / 3

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: MockState.powerModes

                    delegate: Rectangle {
                        required property string modelData

                        width: parent.parent.segmentWidth
                        height: 36
                        radius: height / 2
                        color: MockState.powerMode === modelData ? Theme.accent : Theme.quickTile
                        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: MockState.powerMode === modelData ? Theme.quickIconOn : Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MockState.powerMode = modelData
                        }
                    }
                }
            }
        }
    }
}
