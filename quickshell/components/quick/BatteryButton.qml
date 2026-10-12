import QtQuick
import ".."
import "../../singletons"

// Батарея для шапки панели и для бара: индикатор, процент и молния
// при зарядке. Нажатие открывает панель питания.
Item {
    id: root

    required property int level
    required property bool charging

    signal clicked()

    implicitWidth: content.implicitWidth + 18
    implicitHeight: 34

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
            text: root.level + "%"
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.charging
            text: "\uf0e7"
            color: Theme.chargeColor
            font.family: Theme.iconFontFamily
            font.pixelSize: 11
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hover.hovered ? Theme.quickTileHover : "transparent"
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
