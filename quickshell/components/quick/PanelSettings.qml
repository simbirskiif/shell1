import QtQuick
import ".."
import "../../singletons"

// Настройки оболочки. Пока одна опция — показывать ли процент батареи в баре.
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
                    text: "Show charge level in the bar"
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
    }
}
