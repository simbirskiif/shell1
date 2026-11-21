import QtQml
import QtQuick
import Quickshell
import "../singletons"

// Часы в баре: время — акцентный emphasized-стиль, дата — мелкая подпись
// под ним. Размеры контрастные, как требует Expressive.
MouseArea {
    id: root

    readonly property var enLocale: Qt.locale("en_US")

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        id: column
        spacing: -2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.date.toLocaleTimeString(root.enLocale, "HH:mm")
            color: Theme.barForeground
            font: Theme.typeEmphasizedTitleLarge
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.date.toLocaleDateString(root.enLocale, "dd MMM")
            color: Theme.withAlpha(Theme.scheme.onSurfaceVariant, 0.9)
            font: Theme.typeLabelSmall
        }
    }
}
