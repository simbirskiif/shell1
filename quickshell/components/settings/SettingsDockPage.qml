import QtQuick
import "../../singletons"

// Раздел «Док»: поиск, размеры, положение и поведение раскрытой панели.
// Все значения по-прежнему живут в DockSettings и сохраняются в общий
// settings.json; сюда переехали только элементы управления.
SettingsPage {
    id: root

    readonly property real iconNorm: (DockSettings.iconSize - DockSettings.minIconSize)
        / (DockSettings.maxIconSize - DockSettings.minIconSize)
    readonly property real scrollNorm: (DockSettings.scrollFactor - DockSettings.minScrollFactor)
        / (DockSettings.maxScrollFactor - DockSettings.minScrollFactor)
    readonly property real searchNorm: (DockSettings.searchHeight - DockSettings.minSearchHeight)
        / (DockSettings.maxSearchHeight - DockSettings.minSearchHeight)
    readonly property real panelNorm: (DockSettings.panelMaxHeight - DockSettings.minPanelHeight)
        / (DockSettings.maxPanelHeightLimit - DockSettings.minPanelHeight)

    readonly property string searchStatus: DockSearch.probing ? "Проверяем Elephant…"
        : DockSearch.serviceStarting ? "Запускаем Elephant…"
        : (DockSearch.elephantEnabled
           ? (DockSearch.elephantAvailable ? "Elephant подключён"
              : (DockSearch.installed ? "Elephant установлен, сервис не запущен"
                                      : "Elephant не найден"))
           : "Встроенный поиск")

    readonly property bool searchWarning: DockSearch.elephantEnabled
        && !DockSearch.probing && !DockSearch.serviceStarting
        && (!DockSearch.elephantAvailable || DockSearch.enabledProviders.length === 0)

    title: "Док"
    description: "Размеры и поведение нижней панели приложений."

    Component.onCompleted: {
        if (DockSearch.elephantEnabled && DockSearch.providers.length === 0)
            DockSearch.refresh();
    }

    SettingsCard {
        title: "Поиск"

        SettingsSwitchRow {
            title: "Elephant"
            description: root.searchStatus
            checked: DockSearch.elephantEnabled
            onToggled: DockSearch.setElephantEnabled(!DockSearch.elephantEnabled)
        }

        Rectangle {
            width: parent.width
            height: warningLabel.implicitHeight + Theme.space.lg
            radius: Theme.shape.md
            visible: root.searchWarning
            color: Theme.withAlpha(Theme.warningColor, 0.12)
            border.width: 1
            border.color: Theme.withAlpha(Theme.warningColor, 0.35)

            Text {
                id: warningLabel

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

        SettingsButton {
            text: "Запустить сервис"
            variant: "tonal"
            visible: DockSearch.elephantEnabled && DockSearch.installed
                     && !DockSearch.elephantAvailable
                     && !DockSearch.probing && !DockSearch.serviceStarting
            onClicked: DockSearch.startService()
        }

        Text {
            width: parent.width
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
                    readonly property bool selected: DockSearch.hasProvider(modelData)

                    width: providerLabel.implicitWidth + Theme.space.xl
                    height: 32
                    radius: Theme.shape.full
                    color: selected ? Theme.secondaryContainer : "transparent"
                    border.width: 1
                    border.color: selected ? Theme.secondaryContainer
                                           : Theme.outlineVariant
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.stateLayer(selected
                                                ? Theme.scheme.onSecondaryContainer
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
                        onClicked: DockSearch.toggleProvider(modelData)
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "Иконки и список"

        SettingsSliderRow {
            title: "Размер иконок"
            description: "Высота иконок в компактной полосе"
            value: root.iconNorm
            valueText: DockSettings.iconSize + " px"
            onMoved: v => DockSettings.setIconSize(
                DockSettings.minIconSize + v * (DockSettings.maxIconSize - DockSettings.minIconSize))
        }

        SettingsSwitchRow {
            title: "Плитки вместо строк"
            description: "Сетка приложений в раскрытой панели"
            checked: DockSettings.tileLayout
            onToggled: DockSettings.setTileLayout(!DockSettings.tileLayout)
        }

        SettingsSliderRow {
            title: "Прокрутка"
            description: "Шаг колеса и тачпада в списке приложений"
            value: root.scrollNorm
            valueText: DockSettings.scrollFactor.toFixed(2) + "×"
            onMoved: v => DockSettings.setScrollFactor(
                DockSettings.minScrollFactor + v * (DockSettings.maxScrollFactor - DockSettings.minScrollFactor))
        }
    }

    SettingsCard {
        title: "Поле поиска"

        SettingsSliderRow {
            title: "Высота поля"
            value: root.searchNorm
            valueText: DockSettings.searchHeight + " px"
            onMoved: v => DockSettings.setSearchHeight(
                DockSettings.minSearchHeight + v * (DockSettings.maxSearchHeight - DockSettings.minSearchHeight))
        }

        SettingsChoice {
            title: "Положение"
            options: [
                { key: "top", label: "Сверху" },
                { key: "bottom", label: "Снизу" }
            ]
            value: DockSettings.searchAtBottom ? "bottom" : "top"
            onSelected: key => DockSettings.setSearchAtBottom(key === "bottom")
        }
    }

    SettingsCard {
        title: "Раскрытая панель"

        SettingsSliderRow {
            title: "Максимальная высота"
            value: root.panelNorm
            valueText: DockSettings.panelMaxHeight + " px"
            onMoved: v => DockSettings.setPanelMaxHeight(
                DockSettings.minPanelHeight + v * (DockSettings.maxPanelHeightLimit - DockSettings.minPanelHeight))
        }

        SettingsSwitchRow {
            title: "По размеру списка"
            description: "Панель подстраивается под число приложений"
            checked: DockSettings.fitPanelToContent
            onToggled: DockSettings.setFitPanelToContent(!DockSettings.fitPanelToContent)
        }

        SettingsChoice {
            title: "Кнопка раскрытия"
            options: [
                { key: "left", label: "Слева" },
                { key: "right", label: "Справа" }
            ]
            value: DockSettings.buttonSide
            onSelected: key => DockSettings.setButtonSide(key)
        }
    }

    SettingsButton {
        text: "Сбросить настройки дока"
        variant: "outlined"
        onClicked: DockSettings.reset()
    }
}
