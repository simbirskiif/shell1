import QtQuick
import "../../singletons"
import "../../widgets/core"

// Раздел «Оформление»: откуда берутся цвета и обои, где лежит файл
// настроек и как заставить оболочку перечитать внешние изменения.
SettingsPage {
    id: root

    title: I18n.tr("settings.appearance.title")
    description: I18n.tr("settings.appearance.description")

    SettingsCard {
        title: I18n.tr("settings.appearance.wallpaper.title")

        SettingsRow {
            title: I18n.tr("settings.appearance.palette.title")
            description: Wal.walLoaded
                         ? I18n.tr("settings.appearance.palette.loaded")
                         : I18n.tr("settings.appearance.palette.fallback")

            Rectangle {
                width: Theme.space.xxl
                height: Theme.space.xxl
                radius: Theme.shape.full
                color: Wal.accent
                border.width: 1
                border.color: Theme.outlineVariant
            }
        }

        Item {
            width: parent.width
            implicitHeight: wallpaperLabel.implicitHeight

            Text {
                id: wallpaperLabel

                width: parent.width
                text: Wallpaper.path !== ""
                      ? Wallpaper.path
                      : I18n.tr("settings.appearance.wallpaper.none")
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                wrapMode: Text.WrapAnywhere
            }
        }

        SettingsButton {
            text: I18n.tr("settings.appearance.reload")
            variant: "tonal"
            onClicked: {
                Wal.reload();
                Wallpaper.reload();
            }
        }
    }

    SettingsCard {
        title: I18n.tr("settings.appearance.blur.title")
        description: I18n.tr("settings.appearance.blur.description")

        SettingsSliderRow {
            title: I18n.tr("settings.appearance.blur.strength.title")
            description: I18n.tr("settings.appearance.blur.strength.description")
            value: Theme.blurStrength
            valueText: Math.round(Theme.blurStrength * 100) + "%"
            onMoved: v => Settings.setValue("blur.strength", v)
        }

        SettingsSliderRow {
            title: I18n.tr("settings.appearance.blur.contrast.title")
            description: I18n.tr("settings.appearance.blur.contrast.description")
            value: Theme.cardContrast
            valueText: Math.round(Theme.cardContrast * 100) + "%"
            onMoved: v => Settings.setValue("blur.cardContrast", v)
        }
    }

    SettingsCard {
        title: I18n.tr("settings.appearance.settingsFile.title")
        description: I18n.tr("settings.appearance.settingsFile.description")

        Text {
            width: parent.width
            text: Settings.path
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WrapAnywhere
        }

        Text {
            width: parent.width
            text: I18n.tr("settings.appearance.loaded", {
                state: Settings.loaded ? I18n.tr("common.yes") : I18n.tr("common.no"),
                count: Object.keys(Settings.values).length
            })
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
        }
    }
}
