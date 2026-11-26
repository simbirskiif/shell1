import QtQuick
import "../../singletons"

// Раздел «Плеер»: настройки иконки в баре и вход в панель.
SettingsPage {
    id: root

    title: I18n.tr("settings.player.title")
    description: I18n.tr("settings.player.description")

    SettingsCard {
        title: I18n.tr("settings.player.barIcon.title")

        SettingsSwitchRow {
            title: I18n.tr("settings.player.spectrum.title")
            description: I18n.tr("settings.player.spectrum.description")
            checked: SpectrumService.enabled
            onToggled: SpectrumService.enabled = !SpectrumService.enabled
        }

        Text {
            width: parent.width
            text: I18n.tr("settings.player.spectrum.note")
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        title: I18n.tr("settings.player.panel.title")

        Text {
            width: parent.width
            text: I18n.tr("settings.player.panel.description")
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: Theme.space.sm

            SettingsButton {
                text: I18n.tr("settings.player.openPanel")
                variant: "tonal"
                onClicked: {
                    SettingsWindowState.close();
                    PlayerWindowState.open("");
                }
            }

            SettingsButton {
                text: I18n.tr("settings.player.addToBar")
                variant: "outlined"
                visible: !MockState.barItemPresent("player")
                onClicked: MockState.addBarItem("player")
            }
        }
    }
}
