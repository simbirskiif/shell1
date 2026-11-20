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

        // Разделитель шапки m3 — outline-variant.
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PanelList {
            width: parent.width
            model: ProfileState.profiles

            delegate: Item {
                id: profileRow

                required property string modelData

                readonly property bool current: ProfileState.current === modelData
                // m3 divider между строками: у последней строки списка нет.
                readonly property bool separatorVisible: ListView.view !== null
                    && (profileRow.y + profileRow.height) < ListView.view.contentHeight

                width: parent.width
                height: Theme.listItemHeight

                // Строка списка m3: прозрачный контейнер, hover — state layer.
                Rectangle {
                    anchors.fill: parent
                    color: rowHover.containsMouse
                           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    id: profileLabel

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.lg
                    anchors.right: checkMark.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    elide: Text.ElideRight
                    color: profileRow.current ? Theme.primary : Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                }

                Text {
                    id: checkMark

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    visible: profileRow.current
                    text: "\uf00c"
                    color: Theme.primary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                // Разделитель m3: outline-variant, толщина 1, отступ 16.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.space.lg
                    height: 1
                    color: Theme.outlineVariant
                    visible: profileRow.separatorVisible
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
