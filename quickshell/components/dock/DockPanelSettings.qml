import QtQuick
import Quickshell
import "../quick"
import "../../singletons"

// Настройки дока внутри раскрытой панели. Значения живут в DockSettings
// и сохраняются в общем settings.json. Оформление — M3 settings list:
// строки 56 с переключателем, подписи bodyMedium на onSurfaceVariant,
// слайдеры и чипы на токенах формы и цвета.
Item {
    id: root

    readonly property real iconNorm: (DockSettings.iconSize - DockSettings.minIconSize)
        / (DockSettings.maxIconSize - DockSettings.minIconSize)
    readonly property real scrollNorm: (DockSettings.scrollFactor - DockSettings.minScrollFactor)
        / (DockSettings.maxScrollFactor - DockSettings.minScrollFactor)
    readonly property real searchNorm: (DockSettings.searchHeight - DockSettings.minSearchHeight)
        / (DockSettings.maxSearchHeight - DockSettings.minSearchHeight)
    readonly property real panelNorm: (DockSettings.panelMaxHeight - DockSettings.minPanelHeight)
        / (DockSettings.maxPanelHeightLimit - DockSettings.minPanelHeight)

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        // Небольшой запас снизу: кнопка «Сбросить» не должна упираться
        // в кромку листа, когда список доскроллен до конца.
        contentHeight: column.implicitHeight + Theme.space.lg
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: column
            width: scroller.width
            spacing: Theme.space.lg

            // --- поиск ---
            Column {
                width: parent.width
                spacing: Theme.space.sm

                // M3 list + switch: строка 56, заголовок bodyLarge, подпись
                // bodyMedium цветом onSurfaceVariant.
                Item {
                    width: parent.width
                    height: Theme.listItemHeight

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        width: parent.width - searchSwitch.width - Theme.space.md

                        Text {
                            width: parent.width
                            text: "Поиск"
                            color: Theme.scheme.onSurface
                            font: Theme.typeBodyLarge
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: DockSearch.probing ? "Проверяем Elephant…"
                                : DockSearch.serviceStarting ? "Запускаем Elephant…"
                                : (DockSearch.elephantEnabled
                                   ? (DockSearch.elephantAvailable ? "Elephant подключён"
                                      : (DockSearch.installed ? "Elephant установлен, сервис не запущен"
                                                              : "Elephant не найден"))
                                   : "Встроенный поиск")
                            color: DockSearch.elephantEnabled && !DockSearch.elephantAvailable
                                   && !DockSearch.probing && !DockSearch.serviceStarting
                                   ? Theme.warningColor : Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodyMedium
                            elide: Text.ElideRight
                        }
                    }

                    ToggleSwitch {
                        id: searchSwitch
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: DockSearch.elephantEnabled
                        onToggled: DockSearch.setElephantEnabled(!DockSearch.elephantEnabled)
                    }
                }

                // Предупреждение и одновременно объяснение fallback-а.
                Rectangle {
                    width: parent.width
                    height: warningText.implicitHeight + Theme.space.lg
                    radius: Theme.shape.md
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
                        anchors.margins: Theme.space.sm
                        wrapMode: Text.WordWrap
                        text: !DockSearch.elephantAvailable
                              ? (DockSearch.installed
                                 ? "Elephant установлен, но сервис не запущен — используется встроенный поиск."
                                 : "Elephant не найден — используется встроенный поиск.")
                              : "Не выбран ни один провайдер — используется встроенный поиск."
                        color: Theme.warningColor
                        font: Theme.typeBodySmall
                    }
                }

                // Тональная кнопка M3: secondary-container + on-secondary-container.
                Rectangle {
                    width: 108
                    height: Theme.buttonHeight
                    radius: Theme.shape.full
                    visible: DockSearch.elephantEnabled && DockSearch.installed
                             && !DockSearch.elephantAvailable
                             && !DockSearch.probing && !DockSearch.serviceStarting
                    color: Theme.secondaryContainer
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.stateLayer(Theme.scheme.onSecondaryContainer,
                                                Theme.stateHover)
                        opacity: startHover.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Запустить"
                        color: Theme.scheme.onSecondaryContainer
                        font: Theme.typeLabelLarge
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
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }

                Flow {
                    width: parent.width
                    spacing: Theme.space.sm
                    visible: DockSearch.elephantEnabled

                    Repeater {
                        model: DockSearch.providers

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool selected: DockSearch.hasProvider(modelData)

                            width: providerLabel.implicitWidth + Theme.space.xl
                            height: Theme.space.xxl
                            radius: Theme.shape.full
                            color: selected ? Theme.secondaryContainer : "transparent"
                            border.width: 1
                            // M3 filter chip: выбранный — тональный, обычный —
                            // только обводка outline-variant.
                            border.color: selected ? Theme.secondaryContainer
                                                   : Theme.outlineVariant
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Theme.stateLayer(selected ? Theme.scheme.onSecondaryContainer
                                                                 : Theme.scheme.onSurface,
                                                        Theme.stateHover)
                                opacity: providerHover.containsMouse ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.motionShort3 }
                                }
                            }

                            Text {
                                id: providerLabel
                                anchors.centerIn: parent
                                text: DockSearch.providerLabel(modelData)
                                color: selected ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurfaceVariant
                                font: Theme.typeLabelLarge
                            }

                            MouseArea {
                                id: providerHover
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
                spacing: Theme.space.sm

                Column {
                    width: parent.width
                    // Заголовок 24 + слайдер 32 = строка 56 без разрыва.
                    spacing: 0

                    Item {
                        width: parent.width
                        height: Theme.space.xl

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Размер иконок"
                            color: Theme.scheme.onSurface
                            font: Theme.typeBodyMedium
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: DockSettings.iconSize + " px"
                            color: Theme.primary
                            font: Theme.typeLabelLarge
                        }
                    }

                    PanelSlider {
                        width: parent.width
                        value: root.iconNorm
                        onMoved: v => DockSettings.setIconSize(
                            DockSettings.minIconSize + v * (DockSettings.maxIconSize - DockSettings.minIconSize))
                    }
                }

                // Небольшой предпросмотр: как будут выглядеть избранные иконки.
                Row {
                    spacing: Theme.space.sm
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

            // --- поле поиска ---
            Column {
                width: parent.width
                spacing: Theme.space.sm

                Column {
                    width: parent.width
                    spacing: 0

                    Item {
                        width: parent.width
                        height: Theme.space.xl

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Поле поиска"
                            color: Theme.scheme.onSurface
                            font: Theme.typeBodyMedium
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: DockSettings.searchHeight + " px"
                            color: Theme.primary
                            font: Theme.typeLabelLarge
                        }
                    }

                    PanelSlider {
                        width: parent.width
                        value: root.searchNorm
                        onMoved: v => DockSettings.setSearchHeight(
                            DockSettings.minSearchHeight + v * (DockSettings.maxSearchHeight - DockSettings.minSearchHeight))
                    }
                }

                Row {
                    spacing: Theme.space.sm

                    Repeater {
                        model: [
                            { key: false, label: "Сверху" },
                            { key: true, label: "Снизу" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool selected:
                                DockSettings.searchAtBottom === modelData.key

                            width: 92
                            height: Theme.buttonHeight
                            radius: Theme.shape.full
                            // M3 segmented choice: выбранный — secondary-container.
                            color: selected ? Theme.secondaryContainer : "transparent"
                            border.width: 1
                            border.color: selected ? Theme.secondaryContainer
                                                   : Theme.outlineVariant
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Theme.stateLayer(selected ? Theme.scheme.onSecondaryContainer
                                                                 : Theme.scheme.onSurface,
                                                        Theme.stateHover)
                                opacity: positionHover.containsMouse ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.motionShort3 }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: selected ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurfaceVariant
                                font: Theme.typeLabelLarge
                            }

                            MouseArea {
                                id: positionHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
                                onClicked: DockSettings.setSearchAtBottom(modelData.key)
                            }
                        }
                    }
                }
            }

            // --- панель ---
            Column {
                width: parent.width
                spacing: Theme.space.sm

                Column {
                    width: parent.width
                    spacing: 0

                    Item {
                        width: parent.width
                        height: Theme.space.xl

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Макс. высота панели"
                            color: Theme.scheme.onSurface
                            font: Theme.typeBodyMedium
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: DockSettings.panelMaxHeight + " px"
                            color: Theme.primary
                            font: Theme.typeLabelLarge
                        }
                    }

                    PanelSlider {
                        width: parent.width
                        value: root.panelNorm
                        onMoved: v => DockSettings.setPanelMaxHeight(
                            DockSettings.minPanelHeight + v * (DockSettings.maxPanelHeightLimit - DockSettings.minPanelHeight))
                    }
                }

                // M3 list + switch: строка 56.
                Item {
                    width: parent.width
                    height: Theme.listItemHeight

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - fitSwitch.width - Theme.space.md
                        text: "По размеру списка"
                        color: Theme.scheme.onSurface
                        font: Theme.typeBodyLarge
                        elide: Text.ElideRight
                    }

                    ToggleSwitch {
                        id: fitSwitch
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: DockSettings.fitPanelToContent
                        onToggled: DockSettings.setFitPanelToContent(!DockSettings.fitPanelToContent)
                    }
                }
            }

            // --- сторона кнопки раскрытия ---
            Column {
                width: parent.width
                spacing: Theme.space.sm

                Text {
                    text: "Кнопка раскрытия"
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }

                Row {
                    spacing: Theme.space.sm

                    Repeater {
                        model: [
                            { key: "left", label: "Слева" },
                            { key: "right", label: "Справа" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool selected:
                                DockSettings.buttonSide === modelData.key

                            width: 92
                            height: Theme.buttonHeight
                            radius: Theme.shape.full
                            color: selected ? Theme.secondaryContainer : "transparent"
                            border.width: 1
                            border.color: selected ? Theme.secondaryContainer
                                                   : Theme.outlineVariant
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Theme.stateLayer(selected ? Theme.scheme.onSecondaryContainer
                                                                 : Theme.scheme.onSurface,
                                                        Theme.stateHover)
                                opacity: sideHover.containsMouse ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.motionShort3 }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: selected ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurfaceVariant
                                font: Theme.typeLabelLarge
                            }

                            MouseArea {
                                id: sideHover
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
                spacing: Theme.space.sm

                Column {
                    width: parent.width
                    spacing: 0

                    Item {
                        width: parent.width
                        height: Theme.space.xl

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Прокрутка"
                            color: Theme.scheme.onSurface
                            font: Theme.typeBodyMedium
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: DockSettings.scrollFactor.toFixed(2) + "×"
                            color: Theme.primary
                            font: Theme.typeLabelLarge
                        }
                    }

                    PanelSlider {
                        width: parent.width
                        value: root.scrollNorm
                        onMoved: v => DockSettings.setScrollFactor(
                            DockSettings.minScrollFactor + v * (DockSettings.maxScrollFactor - DockSettings.minScrollFactor))
                    }
                }

                Text {
                    width: parent.width
                    text: "Шаг колеса и тачпада в списке приложений"
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodySmall
                    elide: Text.ElideRight
                }
            }

            // --- сброс ---
            Rectangle {
                id: resetButton
                width: 108
                height: Theme.buttonHeight
                radius: Theme.shape.full
                // M3 outlined button: прозрачный контейнер, обводка outline.
                color: "transparent"
                border.width: 1
                border.color: resetHover.containsMouse ? Theme.outline
                                                      : Theme.outlineVariant
                Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.stateLayer(Theme.primary, Theme.stateHover)
                    opacity: resetHover.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Сбросить"
                    color: Theme.primary
                    font: Theme.typeLabelLarge
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
        width: Theme.space.xs
        color: Theme.outline
        opacity: 0.55
        radius: Theme.shape.full
        visible: scroller.contentHeight > scroller.height
        height: Math.max(20, scroller.height * scroller.height
                         / Math.max(1, scroller.contentHeight))
        y: (scroller.height - height) * (scroller.contentY
            / Math.max(1, scroller.contentHeight - scroller.height))
    }
}
