import QtQuick
import "../../singletons"

// Раздел «Плеер»: настройки иконки в баре и вход в панель.
SettingsPage {
    id: root

    title: "Плеер"
    description: "Иконка со спектром в баре и панель управления."

    SettingsCard {
        title: "Иконка в баре"

        SettingsSwitchRow {
            title: "Спектр"
            description: "Живой анализ аудиопотока; когда ничего не играет, полосы стоят статично"
            checked: SpectrumService.enabled
            onToggled: SpectrumService.enabled = !SpectrumService.enabled
        }

        Text {
            width: parent.width
            text: "Анализируется монитор системного выхода (parec + БПФ). "
                  + "Спектр виден только у действия «Плеер» в баре."
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        title: "Панель"

        Text {
            width: parent.width
            text: "Обложка, трек, перемотка и управление открываются справа под баром."
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: Theme.space.sm

            SettingsButton {
                text: "Открыть панель"
                variant: "tonal"
                onClicked: {
                    SettingsWindowState.close();
                    PlayerWindowState.open("");
                }
            }

            SettingsButton {
                text: "Добавить в бар"
                variant: "outlined"
                visible: !MockState.barItemPresent("player")
                onClicked: MockState.addBarItem("player")
            }
        }
    }
}
