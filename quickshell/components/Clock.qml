import QtQml
import QtQuick
import Quickshell
import "../singletons"

// Дата и время по центру бара: "00:00 12 Oct 2026".
// Клик пока ничего не делает — область нужна как цель для будущего попапа.
MouseArea {
    id: root

    // Месяц всегда на английском, независимо от системной локали.
    // var, а не Locale: тип-значение Locale не резолвится как тип свойства.
    readonly property var enLocale: Qt.locale("en_US")

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    SystemClock {
        id: clock
        // Минутной точности достаточно: формат не содержит секунд.
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Theme.barForeground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.clockFontSize
        text: clock.date.toLocaleTimeString(root.enLocale, "HH:mm") + " " +
              clock.date.toLocaleDateString(root.enLocale, "dd MMM yyyy")
    }
}
