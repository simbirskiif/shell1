import QtQuick
import Quickshell
import "../quick"
import "../../singletons"

// Настройки дока внутри раскрытой панели. Значения живут в DockSettings
// и сохраняются в общем settings.json.
Item {
    id: root

    readonly property real iconNorm: (DockSettings.iconSize - DockSettings.minIconSize)
        / (DockSettings.maxIconSize - DockSettings.minIconSize)
    readonly property real scrollNorm: (DockSettings.scrollFactor - DockSettings.minScrollFactor)
        / (DockSettings.maxScrollFactor - DockSettings.minScrollFactor)

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 18

        // --- размер иконок ---
        Column {
            width: parent.width
            spacing: 8

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Размер иконок"
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: DockSettings.iconSize + " px"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            PanelSlider {
                width: parent.width
                value: root.iconNorm
                onMoved: v => DockSettings.setIconSize(
                    DockSettings.minIconSize + v * (DockSettings.maxIconSize - DockSettings.minIconSize))
            }

            // Небольшой предпросмотр: как будут выглядеть избранные иконки.
            Row {
                spacing: 10
                height: DockSettings.iconSize

                Repeater {
                    model: Math.min(5, DockApps.favorites.length)

                    delegate: Image {
                        required property int index

                        width: DockSettings.iconSize
                        height: DockSettings.iconSize
                        source: {
                            const entry = DockApps.favorites[index];
                            return entry && entry.icon
                                ? Quickshell.iconPath(entry.icon, true) : "";
                        }
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }
                }
            }
        }

        // --- сторона кнопки раскрытия ---
        Column {
            width: parent.width
            spacing: 8

            Text {
                text: "Кнопка раскрытия"
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Row {
                spacing: 8

                Repeater {
                    model: [
                        { key: "left", label: "Слева" },
                        { key: "right", label: "Справа" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: 92
                        height: 30
                        radius: 15
                        color: DockSettings.buttonSide === modelData.key
                               ? Theme.quickTileActive : Theme.quickTile
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: DockSettings.buttonSide === modelData.key
                                   ? Theme.accent : Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
                            onClicked: DockSettings.setButtonSide(modelData.key)
                        }
                    }
                }
            }
        }

        // --- прокрутка сетки ---
        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Прокрутка"
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: DockSettings.scrollFactor.toFixed(2) + "×"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            PanelSlider {
                width: parent.width
                value: root.scrollNorm
                onMoved: v => DockSettings.setScrollFactor(
                    DockSettings.minScrollFactor + v * (DockSettings.maxScrollFactor - DockSettings.minScrollFactor))
            }

            Text {
                width: parent.width
                text: "Шаг колеса и тачпада в сетке приложений"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // --- сброс ---
        Rectangle {
            id: resetButton
            width: 108
            height: 30
            radius: 15
            color: resetHover.containsMouse ? Theme.quickTileHover : Theme.quickTile
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

            Text {
                anchors.centerIn: parent
                text: "Сбросить"
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            MouseArea {
                id: resetHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
                onClicked: DockSettings.reset()
            }
        }
    }
}
