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

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: column
            width: scroller.width
            spacing: 18

            // --- поиск ---
            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 26

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Поиск"
                            color: Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        Text {
                            text: DockSearch.probing ? "Проверяем Elephant…"
                                : DockSearch.serviceStarting ? "Запускаем Elephant…"
                                : (DockSearch.elephantEnabled
                                   ? (DockSearch.elephantAvailable ? "Elephant подключён"
                                      : (DockSearch.installed ? "Elephant установлен, сервис не запущен"
                                                              : "Elephant не найден"))
                                   : "Встроенный поиск")
                            color: DockSearch.elephantEnabled && !DockSearch.elephantAvailable
                                   && !DockSearch.probing && !DockSearch.serviceStarting
                                   ? Theme.warningColor : Theme.quickTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }

                    ToggleSwitch {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: DockSearch.elephantEnabled
                        onToggled: DockSearch.setElephantEnabled(!DockSearch.elephantEnabled)
                    }
                }

                // Предупреждение и одновременно объяснение fallback-а.
                Rectangle {
                    width: parent.width
                    height: warningText.implicitHeight + 16
                    radius: 10
                    visible: DockSearch.elephantEnabled && !DockSearch.probing
                             && !DockSearch.serviceStarting
                             && (!DockSearch.elephantAvailable
                                 || DockSearch.enabledProviders.length === 0)
                    color: Theme.withAlpha(Theme.warningColor, 0.12)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.warningColor, 0.35)

                    Text {
                        id: warningText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        wrapMode: Text.WordWrap
                        text: !DockSearch.elephantAvailable
                              ? (DockSearch.installed
                                 ? "Elephant установлен, но сервис не запущен — используется встроенный поиск."
                                 : "Elephant не найден — используется встроенный поиск.")
                              : "Не выбран ни один провайдер — используется встроенный поиск."
                        color: Theme.warningColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    width: 108
                    height: 28
                    radius: 14
                    visible: DockSearch.elephantEnabled && DockSearch.installed
                             && !DockSearch.elephantAvailable
                             && !DockSearch.probing && !DockSearch.serviceStarting
                    color: startHover.containsMouse ? Theme.quickTileHover : Theme.quickTile
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Запустить"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: startHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
                        onClicked: DockSearch.startService()
                    }
                }

                Text {
                    visible: DockSearch.elephantEnabled && DockSearch.providers.length > 0
                    text: "Провайдеры Elephant"
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Flow {
                    width: parent.width
                    spacing: 8
                    visible: DockSearch.elephantEnabled

                    Repeater {
                        model: DockSearch.providers

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool selected: DockSearch.hasProvider(modelData)

                            width: providerLabel.implicitWidth + 24
                            height: 28
                            radius: 14
                            color: selected ? Theme.quickTileActive : Theme.quickTile
                            border.width: 1
                            border.color: selected ? Theme.accent : Theme.quickBorder
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                            Text {
                                id: providerLabel
                                anchors.centerIn: parent
                                text: DockSearch.providerLabel(modelData)
                                color: selected ? Theme.accent : Theme.quickText
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
                                onClicked: DockSearch.toggleProvider(modelData)
                            }
                        }
                    }
                }
            }

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

        // --- прокрутка списка ---
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
                text: "Шаг колеса и тачпада в списке приложений"
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

    // Тонкий индикатор прокрутки: настройки теперь длиннее панели.
    Rectangle {
        id: scrollThumb
        anchors.right: parent.right
        anchors.rightMargin: 1
        width: 3
        radius: 1.5
        color: Theme.quickTextDim
        opacity: 0.55
        visible: scroller.contentHeight > scroller.height
        height: Math.max(20, scroller.height * scroller.height
                         / Math.max(1, scroller.contentHeight))
        y: (scroller.height - height) * (scroller.contentY
            / Math.max(1, scroller.contentHeight - scroller.height))
    }
}
