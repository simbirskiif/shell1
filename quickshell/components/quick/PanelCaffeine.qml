import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Панель «Кофеин»: выбор срока — из настроенных длительностей и бесконечного.
// Пункта «выключен» здесь нет: выключение делает переключатель в шапке или
// кружок плитки.
//
// Expressive: выбранный срок — крупная пилюля tertiary-container с орбом-
// «солнышком»; остальные строки прозрачные с hover-слоем. Разделителей нет.
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
            title: "Кофеин"
            checked: CaffeineService.active
            onBackRequested: root.backRequested()
            onToggled: CaffeineService.toggle()
        }

        PanelList {
            width: parent.width
            rowHeight: 62
            model: CaffeineService.options

            delegate: Item {
                id: modeRow

                required property var modelData

                readonly property bool current: CaffeineService.mode === modelData.key
                readonly property bool hovered: modeHover.containsMouse
                readonly property bool pressed: modeHover.pressed

                readonly property color rowColor: current ? Theme.tertiaryContainer
                                                  : hovered ? Theme.surfaceContainerHigh
                                                  : "transparent"
                readonly property color ink: current ? Theme.scheme.onTertiaryContainer
                                                     : Theme.scheme.onSurface

                width: parent.width
                height: 62

                scale: pressed ? 0.98 : 1
                Behavior on scale { SpringSpatialFast {} }

                MorphShape {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    shape: modeRow.current ? "pill" : "squircle"
                    color: modeRow.rowColor
                    modulation: 0.35

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                // Орб режима: активный — «солнышко» primary-контейнера.
                MorphShape {
                    id: modeOrb
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    shape: modeRow.current ? "sunny" : (modeRow.hovered ? "cookie" : "circle")
                    color: modeRow.current ? Theme.primaryContainer : Theme.surfaceContainerHighest
                    modulation: 1

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0f4"
                        color: modeRow.current ? Theme.scheme.onPrimaryContainer
                                               : Theme.scheme.onSurfaceVariant
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 20
                    }
                }

                Text {
                    id: modeLabel
                    anchors.left: modeOrb.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: checkMark.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title
                    elide: Text.ElideRight
                    color: modeRow.ink
                    font: modeRow.current ? Theme.typeEmphasizedLabelLarge : Theme.typeBodyLarge
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: checkMark
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modeRow.current
                    text: "\uf00c"
                    color: Theme.scheme.onTertiaryContainer
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                MouseArea {
                    id: modeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CaffeineService.setMode(modelData.key)
                }
            }
        }
    }
}
