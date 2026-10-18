import QtQuick

// solid + статичная шумовая текстура. Шум — PNG-тайл, чтобы не перерисовывать
// шейдер каждый кадр.
Item {
    id: root

    property var colors: ({})
    property real radius: 0
    property var size: Qt.size(0, 0)
    property string wallpaperSource: ""
    property bool editing: false
    property real offsetX: 0
    property real offsetY: 0
    property real screenWidth: 0
    property real screenHeight: 0

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.colors.surface || "#1C1B1F"
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.colors.surfaceVariant || "#49454F"
        opacity: 0.35
    }

    Image {
        anchors.fill: parent
        source: "noise.png"
        fillMode: Image.Tile
        opacity: 0.9
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.colors.outline || "#938F99"
        opacity: 0.35
    }
}
