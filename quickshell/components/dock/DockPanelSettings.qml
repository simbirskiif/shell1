import QtQuick
import Quickshell
import "../quick"
import "../expressive"
import "../../singletons"

// Настройки дока внутри раскрытой панели. Значения живут в DockSettings
// и сохраняются в общем settings.json. Оформление — M3 Expressive settings:
// строки 56 с переключателем (ToggleSwitch уже expressive), подписи
// bodyMedium, слайдеры с волнистой дорожкой, а чипы провайдеров и позиции —
// пилюли на tertiary-container, которые деформируются при нажатии.
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

    // Общий вид чипа-пилюли: выбранный — tertiary-container, обычный —
    // тональная поверхность. При нажатии контур становится squircle, а
    // чип сжимается: отклик читается формой, а не обводкой.
    // (Вложенные объекты вместо `component` — inline-компоненты в этой
    // сборке ломают конфиг.)

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
                // Мягкий цветной контейнер без тонкой обводки — состояние
                // читается заливкой и маркером, а не рамкой.
                Item {
                    width: parent.width
                    height: warningText.implicitHeight + Theme.space.lg
                    visible: DockSearch.elephantEnabled && !DockSearch.probing
                             && !DockSearch.serviceStarting
                             && (!DockSearch.elephantAvailable
                                 || DockSearch.enabledProviders.length === 0)

                    MorphShape {
                        anchors.fill: parent
                        shape: "squircle"
                        modulation: 0.3
                        color: Theme.withAlpha(Theme.warningColor, 0.16)
                    }

                    MorphShape {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.md
                        anchors.top: parent.top
                        anchors.topMargin: Theme.space.sm + 2
                        width: 8
                        height: 8
                        shape: "cookie"
                        color: Theme.warningColor
                    }

                    Text {
                        id: warningText
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.xl
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.md
                        anchors.top: parent.top
                        anchors.topMargin: Theme.space.sm
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

                // Тональная кнопка M3: tertiary-container + on-tertiary-container.
                // Нажатие деформирует пилюлю, поэтому это не «плоский» chip.
                Item {
                    width: 116
                    height: Theme.buttonHeight
                    visible: DockSearch.elephantEnabled && DockSearch.installed
                             && !DockSearch.elephantAvailable
                             && !DockSearch.probing && !DockSearch.serviceStarting

                    readonly property bool hovered: startHover.containsMouse
                    readonly property bool pressed: startHover.pressed

                    scale: pressed ? 0.95 : (hovered ? 1.03 : 1)
                    Behavior on scale { SpringSpatialFast {} }

                    MorphShape {
                        anchors.fill: parent
                        shape: startHover.pressed ? "squircle" : "pill"
                        modulation: 0.45
                        color: Theme.tertiaryContainer
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Запустить"
                        color: Theme.scheme.onTertiaryContainer
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

                        delegate: Item {
                            id: providerChip

                            required property var modelData

                            readonly property bool selected: DockSearch.hasProvider(modelData)
                            readonly property bool hovered: providerHover.containsMouse
                            readonly property bool pressed: providerHover.pressed

                            width: providerLabel.implicitWidth + Theme.space.xl + Theme.space.sm
                            height: 40

                            scale: pressed ? 0.94 : (hovered ? 1.03 : 1)
                            Behavior on scale { SpringSpatialFast {} }

                            // Пилюля-чип: активный — tertiary-container,
                            // обычный — тональная поверхность; при нажатии
                            // контур схлопывается в squircle.
                            MorphShape {
                                anchors.fill: parent
                                shape: providerHover.pressed ? "squircle" : "pill"
                                modulation: providerHover.pressed ? 0.6 : 0.35
                                color: providerChip.selected ? Theme.tertiaryContainer
                                     : providerChip.hovered ? Theme.surfaceContainerHighest
                                     : Theme.surfaceContainerHigh
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Text {
                                id: providerLabel
                                anchors.centerIn: parent
                                text: DockSearch.providerLabel(providerChip.modelData)
                                color: providerChip.selected ? Theme.scheme.onTertiaryContainer
                                                             : Theme.scheme.onSurfaceVariant
                                font: providerChip.selected ? Theme.typeEmphasizedLabelLarge
                                                            : Theme.typeLabelLarge
                                scale: providerChip.pressed ? 0.96 : 1
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on scale { SpringSpatialFast {} }
                            }

                            MouseArea {
                                id: providerHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
                                onClicked: DockSearch.toggleProvider(providerChip.modelData)
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
                            font: Theme.typeEmphasizedLabelLarge
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
                            font: Theme.typeEmphasizedLabelLarge
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

                        delegate: Item {
                            id: positionChip

                            required property var modelData

                            readonly property bool selected:
                                DockSettings.searchAtBottom === modelData.key
                            readonly property bool hovered: positionHover.containsMouse
                            readonly property bool pressed: positionHover.pressed

                            width: 100
                            height: Theme.buttonHeight

                            scale: pressed ? 0.94 : (hovered ? 1.03 : 1)
                            Behavior on scale { SpringSpatialFast {} }

                            MorphShape {
                                anchors.fill: parent
                                shape: positionHover.pressed ? "squircle" : "pill"
                                modulation: positionHover.pressed ? 0.6 : 0.35
                                color: positionChip.selected ? Theme.tertiaryContainer
                                     : positionChip.hovered ? Theme.surfaceContainerHighest
                                     : Theme.surfaceContainerHigh
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: positionChip.modelData.label
                                color: positionChip.selected ? Theme.scheme.onTertiaryContainer
                                                            : Theme.scheme.onSurfaceVariant
                                font: positionChip.selected ? Theme.typeEmphasizedLabelLarge
                                                            : Theme.typeLabelLarge
                                scale: positionChip.pressed ? 0.96 : 1
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on scale { SpringSpatialFast {} }
                            }

                            MouseArea {
                                id: positionHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
                                onClicked: DockSettings.setSearchAtBottom(positionChip.modelData.key)
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
                            font: Theme.typeEmphasizedLabelLarge
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

                        delegate: Item {
                            id: sideChip

                            required property var modelData

                            readonly property bool selected:
                                DockSettings.buttonSide === modelData.key
                            readonly property bool hovered: sideHover.containsMouse
                            readonly property bool pressed: sideHover.pressed

                            width: 100
                            height: Theme.buttonHeight

                            scale: pressed ? 0.94 : (hovered ? 1.03 : 1)
                            Behavior on scale { SpringSpatialFast {} }

                            MorphShape {
                                anchors.fill: parent
                                shape: sideHover.pressed ? "squircle" : "pill"
                                modulation: sideHover.pressed ? 0.6 : 0.35
                                color: sideChip.selected ? Theme.tertiaryContainer
                                     : sideChip.hovered ? Theme.surfaceContainerHighest
                                     : Theme.surfaceContainerHigh
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: sideChip.modelData.label
                                color: sideChip.selected ? Theme.scheme.onTertiaryContainer
                                                         : Theme.scheme.onSurfaceVariant
                                font: sideChip.selected ? Theme.typeEmphasizedLabelLarge
                                                        : Theme.typeLabelLarge
                                scale: sideChip.pressed ? 0.96 : 1
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on scale { SpringSpatialFast {} }
                            }

                            MouseArea {
                                id: sideHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
                                onClicked: DockSettings.setButtonSide(sideChip.modelData.key)
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
                            font: Theme.typeEmphasizedLabelLarge
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
            Item {
                id: resetButton
                width: 116
                height: Theme.buttonHeight

                readonly property bool hovered: resetHover.containsMouse
                readonly property bool pressed: resetHover.pressed

                scale: pressed ? 0.94 : (hovered ? 1.03 : 1)
                Behavior on scale { SpringSpatialFast {} }

                // Заполненная тональная кнопка вместо outlined: без тонкой
                // рамки, нажатие деформирует пилюлю в squircle.
                MorphShape {
                    anchors.fill: parent
                    shape: resetHover.pressed ? "squircle" : "pill"
                    modulation: resetHover.pressed ? 0.55 : 0.3
                    color: resetButton.hovered ? Theme.surfaceContainerHighest
                                               : Theme.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Сбросить"
                    color: Theme.scheme.onSurface
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

    // Индикатор прокрутки: настройки длиннее панели. Крупная пилюля вместо
    // тонкой линии — читается и на светлой, и на тёмной теме.
    Rectangle {
        id: scrollThumb
        anchors.right: parent.right
        anchors.rightMargin: 1
        width: Theme.space.xs + 2
        color: Theme.tertiary
        opacity: 0.7
        radius: Theme.shape.full
        visible: scroller.contentHeight > scroller.height
        height: Math.max(20, scroller.height * scroller.height
                         / Math.max(1, scroller.contentHeight))
        y: (scroller.height - height) * (scroller.contentY
            / Math.max(1, scroller.contentHeight - scroller.height))
    }
}
