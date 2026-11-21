import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Строка текущего устройства: подпись и стрелка «открыть список».
// Нажатие открывает отдельную панель выбора устройств.
//
// Expressive: это выбранное устройство, поэтому строка — крупная пилюля
// secondary-container с орбом-sunny; на hover форма деформируется в squircle.
Item {
    id: root

    required property string icon
    required property string text

    signal clicked()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 64
    height: implicitHeight

    readonly property bool hovered: deviceHover.containsMouse
    readonly property bool pressed: deviceHover.pressed

    scale: root.pressed ? 0.98 : (root.hovered ? 1.01 : 1)
    Behavior on scale { SpringSpatialFast {} }

    MorphShape {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        shape: root.hovered ? "squircle" : "pill"
        color: root.hovered ? Theme.secondaryContainer : Theme.primaryContainer
        modulation: 0.35

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // Орб устройства: tertiary-контейнер внутри primary-пилюли.
    MorphShape {
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: 48
        shape: root.hovered ? "cookie" : "circle"
        color: Theme.tertiaryContainer
        modulation: 1

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: Theme.scheme.onTertiaryContainer
            font.family: Theme.iconFontFamily
            font.pixelSize: 22
        }
    }

    Text {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: 60
        anchors.right: chevron.left
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        text: root.text !== "" ? root.text : "No device"
        elide: Text.ElideRight
        color: root.hovered ? Theme.scheme.onSecondaryContainer
                            : Theme.scheme.onPrimaryContainer
        font: Theme.typeEmphasizedLabelLarge
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf054"
        color: root.hovered ? Theme.scheme.onSecondaryContainer
                            : Theme.scheme.onPrimaryContainer
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.md
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        id: deviceHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
