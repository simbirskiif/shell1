import QtQuick
import "../../singletons"
import "../quick"

// Строка списка с переключателем M3. Отдельный компонент, чтобы страницы
// не повторяли связку «подпись + ToggleSwitch + сигнал».
SettingsRow {
    id: root

    required property bool checked

    signal toggled()

    ToggleSwitch {
        checked: root.checked
        onToggled: root.toggled()
    }
}
