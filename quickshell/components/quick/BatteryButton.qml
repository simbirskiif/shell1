import QtQuick
import ".."
import "../../singletons"

// Батарея для шапки панели и для бара: индикатор, процент и молния
// при зарядке. Нажатие открывает панель питания.
Item {
    id: root

    required property int level
    required property bool charging

    // В баре процент можно отключить в настройках — иконка остаётся.
    property bool showPercent: true

    signal clicked()

    // M3: кнопка-пилюля, как соседние действия в баре.
    implicitWidth: content.implicitWidth + 20
    implicitHeight: Theme.iconButtonSize

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        BatteryIndicator {
            anchors.verticalCenter: parent.verticalCenter
            level: root.level
            charging: root.charging
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // оптическое выравнивание: строка шрифта выше центра иконки
            anchors.verticalCenterOffset: 1
            visible: root.showPercent
            text: root.level + "%"
            color: Theme.quickText
            font: Theme.typeLabelLarge
        }

    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hover.containsMouse ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
