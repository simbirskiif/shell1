import QtQuick
import ".."
import "../../singletons"

// Панель яркости: слайдер во всю ширину с иконкой и процентом.
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
            title: "Brightness"
            checked: false
            switchable: false
            onBackRequested: root.backRequested()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        Item {
            width: parent.width
            height: 76

            Text {
                id: brightnessIcon
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf185"
                color: Theme.quickTextDim
                font.family: Theme.iconFontFamily
                font.pixelSize: 15
            }

            Text {
                id: percentText
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(MockState.brightness * 100) + "%"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            PanelSlider {
                anchors.left: brightnessIcon.right
                anchors.leftMargin: 16
                anchors.right: percentText.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                height: 22
                value: MockState.brightness
                onMoved: v => {
                    MockState.brightness = v;
                }
            }
        }
    }
}
