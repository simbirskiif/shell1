import QtQuick
import "../../singletons"

// Раздел «Язык»: явный язык интерфейса и запасной язык приложения.
//
// Режим «Как в системе» читает локаль окружения; если такой язык не
// поддерживается (или локаль не определена), действует запасной. Все строки
// окна пересчитываются сами: I18n.tr() — обычная привязка.
SettingsPage {
    id: root

    readonly property string detectedText: I18n.systemLocale === ""
        ? I18n.tr("settings.language.detectedUnsupported", { language: "—" })
        : (I18n.systemLanguage !== ""
           ? I18n.tr("settings.language.detected",
                     { language: I18n.nameFor(I18n.systemLanguage) + " (" + I18n.systemLocale + ")" })
           : I18n.tr("settings.language.detectedUnsupported", { language: I18n.systemLocale }))

    title: I18n.tr("settings.language.title")
    description: I18n.tr("settings.language.description")

    function languageOptions() {
        const list = [{ key: "system", label: I18n.tr("settings.language.system") }];
        for (let i = 0; i < I18n.supported.length; ++i) {
            list.push({ key: I18n.supported[i].code, label: I18n.supported[i].name });
        }
        return list;
    }

    function fallbackOptions() {
        const list = [];
        for (let i = 0; i < I18n.supported.length; ++i)
            list.push({ key: I18n.supported[i].code, label: I18n.supported[i].name });
        return list;
    }

    SettingsCard {
        title: I18n.tr("settings.language.interface.title")
        description: I18n.tr("settings.language.interface.description")

        SettingsChoice {
            options: root.languageOptions()
            value: I18n.mode
            onSelected: key => I18n.setMode(key)
        }

        Text {
            width: parent.width
            text: root.detectedText
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: I18n.tr("settings.language.current", { language: I18n.languageName })
            color: Theme.primary
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        title: I18n.tr("settings.language.fallback.title")
        description: I18n.tr("settings.language.fallback.description")

        SettingsChoice {
            description: I18n.tr("settings.language.fallback.note")
            options: root.fallbackOptions()
            value: I18n.fallback
            onSelected: key => I18n.setFallback(key)
        }
    }
}
