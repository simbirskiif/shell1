// Точка входа конфигурации Quickshell.
// По одному бару на каждый экран; сам бар живёт в components/Bar.qml.
import Quickshell
import "components"

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }
}
