import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Панель «Профиль»: список всех profiles из ~/.config/hypr/profiles.
// Клик по строке переключает hypr-profile и возвращает в сетку.
//
// Expressive: текущий профиль — крупная пилюля primary-container с орбом-
// «клевером»; остальные строки прозрачные с hover-слоем. Разделителей нет.
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

        PanelList {
            width: parent.width
            rowHeight: 62
            model: ProfileState.profiles

            delegate: Item {
                id: profileRow

                required property string modelData

                readonly property bool current: ProfileState.current === modelData
                readonly property bool hovered: rowHover.containsMouse
                readonly property bool pressed: rowHover.pressed

                readonly property color rowColor: current ? Theme.primaryContainer
                                                  : hovered ? Theme.surfaceContainerHigh
                                                  : "transparent"
                readonly property color ink: current ? Theme.scheme.onPrimaryContainer
                                                     : Theme.scheme.onSurface

                width: parent.width
                height: 62

                scale: pressed ? 0.98 : 1
                Behavior on scale { SpringSpatialFast {} }

                MorphShape {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    shape: profileRow.current ? "pill" : "squircle"
                    color: profileRow.rowColor
                    modulation: 0.35

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                // Орб профиля: выбранный — «клевер» tertiary-контейнера.
                MorphShape {
                    id: profileOrb
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    shape: profileRow.current ? "clover" : (profileRow.hovered ? "cookie" : "circle")
                    color: profileRow.current ? Theme.tertiaryContainer : Theme.surfaceContainerHighest
                    modulation: 1

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00a"
                        color: profileRow.current ? Theme.scheme.onTertiaryContainer
                                                  : Theme.scheme.onSurfaceVariant
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 20
                    }
                }

                Text {
                    id: profileLabel

                    anchors.left: profileOrb.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: checkMark.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    elide: Text.ElideRight
                    color: profileRow.ink
                    font: profileRow.current ? Theme.typeEmphasizedLabelLarge : Theme.typeBodyLarge
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: checkMark

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    visible: profileRow.current
                    text: "\uf00c"
                    color: Theme.scheme.onPrimaryContainer
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
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
