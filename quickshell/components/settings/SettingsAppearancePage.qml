import QtQuick
import "../../singletons"
import "../../widgets/core"

// Раздел «Оформление»: откуда берутся цвета и обои, где лежит файл
// настроек и как заставить оболочку перечитать внешние изменения.
SettingsPage {
    id: root

    title: "Оформление"
    description: "Палитра строится из обоев (pywal). Здесь же — служебные пути."

    SettingsCard {
        title: "Обои и палитра"

        SettingsRow {
            title: "Палитра"
            description: Wal.walLoaded
                         ? "Загружена из pywal"
                         : "pywal не найден — используется запасная схема"

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
                      : "Обои не заданы — материал glass спросит hyprpaper"
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                wrapMode: Text.WrapAnywhere
            }
        }

        SettingsButton {
            text: "Перечитать палитру и обои"
            variant: "tonal"
            onClicked: {
                Wal.reload();
                Wallpaper.reload();
            }
        }
    }

    SettingsCard {
        title: "Файл настроек"
        description: "Настройки оболочки хранятся в состоянии пользователя и переживают перезапуск."

        Text {
            width: parent.width
            text: Settings.path
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WrapAnywhere
        }

        Text {
            width: parent.width
            text: "Загружено: " + (Settings.loaded ? "да" : "нет")
                  + " · ключей: " + Object.keys(Settings.values).length
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
        }
    }
}
