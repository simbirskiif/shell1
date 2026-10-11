import QtQuick
import "../../singletons"

// Внутренняя панель звука: переключатель-мьют и слайдер громкости.
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
            title: "Sound"
            checked: MockState.soundEnabled
            onBackRequested: root.backRequested()
            onToggled: MockState.toggleSound()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        Item {
            width: parent.width
            height: 96

            Text {
                id: volumeIcon
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.top: parent.top
                anchors.topMargin: 22
                text: MockState.soundEnabled ? "\uf028" : "\uf026"
                color: MockState.soundEnabled ? Theme.quickText : Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 16
                Behavior on color { ColorAnimation { duration: Theme.quickViewDuration } }
            }

            Text {
                id: percent
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: volumeIcon.verticalCenter
                text: Math.round(MockState.volume * 100) + "%"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            VolumeSlider {
                anchors.left: volumeIcon.right
                anchors.leftMargin: 16
                anchors.right: percent.left
                anchors.rightMargin: 16
                anchors.verticalCenter: volumeIcon.verticalCenter
                height: 22
                value: MockState.volume
                onMoved: v => {
                    MockState.volume = v;
                }
            }

            Text {
                anchors.left: volumeIcon.right
                anchors.leftMargin: 16
                anchors.top: volumeIcon.bottom
                anchors.topMargin: 18
                text: MockState.outputName
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
