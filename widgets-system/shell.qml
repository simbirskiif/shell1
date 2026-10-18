// Точка входа системы виджетов рабочего стола.
//
// Запуск: qs -p /path/to/widgets-system
// На каждый экран создаётся отдельный DesktopLayer. Variants сам реагирует
// на подключение/отключение мониторов и смену их геометрии.
import QtQuick
import Quickshell
import "desktop"
import "core"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: DesktopLayer {
            required property var modelData

            screen: modelData
        }
    }

    Component.onCompleted: {
        console.info("[widgets] shell started, screens=" + Quickshell.screens.length
                     + ", путей поиска: " + WidgetRegistry.searchPaths.length)
    }
}
