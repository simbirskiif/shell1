import QtQuick
import ".."
import "../../singletons"

// Панель «Профиль»: список всех profiles из ~/.config/hypr/profiles.
// Клик по строке переключает hypr-profile и возвращает в сетку.
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
            title: "Профиль"
            checked: ProfileState.current !== "default"
            switchable: false
            onBackRequested: root.backRequested()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        PanelList {
            width: parent.width
            model: ProfileState.profiles

            delegate: Item {
                required property string modelData

                readonly property bool current: ProfileState.current === modelData

                width: parent.width
                height: Theme.quickRowHeight

                Rectangle {
                    anchors.fill: parent
                    color: rowHover.hovered ? Theme.quickTileHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    id: profileLabel

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: checkMark.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    elide: Text.ElideRight
                    color: current ? Theme.accent : Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                }

                Text {
                    id: checkMark

                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: current
                    text: "\uf00c"
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 13
                }

                MouseArea {
                    id: rowHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ProfileState.switchTo(modelData);
                        root.backRequested();
                    }
                }
            }
        }
    }
}
