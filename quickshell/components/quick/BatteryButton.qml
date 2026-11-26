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
    // Пользовательская иконка из настроек бара. Пусто — живой индикатор.
    property string iconOverride: ""

    signal clicked()

    // M3: кнопка-пилюля, как соседние действия в баре. Индикатор и процент
    // занимают по слоту общей сетки: при включённом проценте кнопка
    // расширяется влево ровно на слот с зазором, поэтому батарейка не
    // съезжает с шага между иконками.
    implicitWidth: iconSlot.width
                   + (percentSlot.visible ? Theme.barIconGap + percentSlot.width : 0)
    implicitHeight: Theme.barIconSlot

    Row {
        id: content
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barIconGap

        Item {
            id: iconSlot
            width: Theme.barIconSlot
            height: Theme.barIconSlot

            BatteryIndicator {
                anchors.centerIn: parent
                visible: root.iconOverride === ""
                level: root.level
                charging: root.charging
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                visible: root.iconOverride !== ""
                text: root.iconOverride
                color: Theme.quickText
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.sm
            }
        }

        Item {
            id: percentSlot
            width: Theme.barIconSlot
            height: Theme.barIconSlot
            visible: root.showPercent

            Text {
                anchors.centerIn: parent
                // оптическое выравнивание: строка шрифта выше центра иконки
                anchors.verticalCenterOffset: 1
                text: root.level + "%"
                color: Theme.quickText
                font: Theme.typeLabelLarge
            }
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
