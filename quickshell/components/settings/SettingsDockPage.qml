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

    readonly property string searchStatus: DockSearch.probing
        ? I18n.tr("settings.dock.search.probing")
        : DockSearch.serviceStarting ? I18n.tr("settings.dock.search.starting")
        : (DockSearch.elephantEnabled
           ? (DockSearch.elephantAvailable ? I18n.tr("settings.dock.search.connected")
              : (DockSearch.installed ? I18n.tr("settings.dock.search.installed")
                                      : I18n.tr("settings.dock.search.missing")))
           : I18n.tr("settings.dock.search.builtin"))

    readonly property bool searchWarning: DockSearch.elephantEnabled
        && !DockSearch.probing && !DockSearch.serviceStarting
        && (!DockSearch.elephantAvailable || DockSearch.enabledProviders.length === 0)

    title: I18n.tr("settings.dock.title")
    description: I18n.tr("settings.dock.description")

    Component.onCompleted: {
        if (DockSearch.elephantEnabled && DockSearch.providers.length === 0)
            DockSearch.refresh();
    }

    SettingsCard {
        title: I18n.tr("settings.dock.search.title")

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
                         ? I18n.tr("settings.dock.search.warning.installed")
                         : I18n.tr("settings.dock.search.warning.missing"))
                      : I18n.tr("settings.dock.search.warning.noProvider")
                color: Theme.warningColor
                font: Theme.typeBodySmall
            }
        }

        SettingsButton {
            text: I18n.tr("settings.dock.startService")
            variant: "tonal"
            visible: DockSearch.elephantEnabled && DockSearch.installed
                     && !DockSearch.elephantAvailable
                     && !DockSearch.probing && !DockSearch.serviceStarting
            onClicked: DockSearch.startService()
        }

        Text {
            width: parent.width
            visible: DockSearch.elephantEnabled && DockSearch.providers.length > 0
            text: I18n.tr("settings.dock.providers")
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
        title: I18n.tr("settings.dock.icons.title")

        SettingsSliderRow {
            title: I18n.tr("settings.dock.iconSize.title")
            description: I18n.tr("settings.dock.iconSize.description")
            value: root.iconNorm
            valueText: DockSettings.iconSize + " px"
            onMoved: v => DockSettings.setIconSize(
                DockSettings.minIconSize + v * (DockSettings.maxIconSize - DockSettings.minIconSize))
        }

        SettingsSwitchRow {
            title: I18n.tr("settings.dock.tiles.title")
            description: I18n.tr("settings.dock.tiles.description")
            checked: DockSettings.tileLayout
            onToggled: DockSettings.setTileLayout(!DockSettings.tileLayout)
        }

        SettingsSliderRow {
            title: I18n.tr("settings.dock.scroll.title")
            description: I18n.tr("settings.dock.scroll.description")
            value: root.scrollNorm
            valueText: DockSettings.scrollFactor.toFixed(2) + "×"
            onMoved: v => DockSettings.setScrollFactor(
                DockSettings.minScrollFactor + v * (DockSettings.maxScrollFactor - DockSettings.minScrollFactor))
        }
    }

    SettingsCard {
        title: I18n.tr("settings.dock.searchField.title")

        SettingsSliderRow {
            title: I18n.tr("settings.dock.searchHeight.title")
            value: root.searchNorm
            valueText: DockSettings.searchHeight + " px"
            onMoved: v => DockSettings.setSearchHeight(
                DockSettings.minSearchHeight + v * (DockSettings.maxSearchHeight - DockSettings.minSearchHeight))
        }

        SettingsChoice {
            title: I18n.tr("settings.dock.position.title")
            options: [
                { key: "top", label: I18n.tr("settings.dock.position.top") },
                { key: "bottom", label: I18n.tr("settings.dock.position.bottom") }
            ]
            value: DockSettings.searchAtBottom ? "bottom" : "top"
            onSelected: key => DockSettings.setSearchAtBottom(key === "bottom")
        }
    }

    SettingsCard {
        title: I18n.tr("settings.dock.expanded.title")

        SettingsSliderRow {
            title: I18n.tr("settings.dock.maxHeight.title")
            value: root.panelNorm
            valueText: DockSettings.panelMaxHeight + " px"
            onMoved: v => DockSettings.setPanelMaxHeight(
                DockSettings.minPanelHeight + v * (DockSettings.maxPanelHeightLimit - DockSettings.minPanelHeight))
        }

        SettingsSwitchRow {
            title: I18n.tr("settings.dock.fit.title")
            description: I18n.tr("settings.dock.fit.description")
            checked: DockSettings.fitPanelToContent
            onToggled: DockSettings.setFitPanelToContent(!DockSettings.fitPanelToContent)
        }

        SettingsChoice {
            title: I18n.tr("settings.dock.buttonSide.title")
            options: [
                { key: "left", label: I18n.tr("settings.dock.buttonSide.left") },
                { key: "right", label: I18n.tr("settings.dock.buttonSide.right") }
            ]
            value: DockSettings.buttonSide
            onSelected: key => DockSettings.setButtonSide(key)
        }
    }

    SettingsButton {
        text: I18n.tr("settings.dock.reset")
        variant: "outlined"
        onClicked: DockSettings.reset()
    }
}
