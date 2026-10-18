import QtQuick

// Градиент из палитры shell.
Item {
    id: root

    property var colors: ({})
    property real radius: 0
    property real dim: 0.60
    property var widgetsBackdrop: null
    property var size: Qt.size(0, 0)
    property string wallpaperSource: ""
    property bool editing: false
    property real offsetX: 0
    property real offsetY: 0
    property real localX: 0
    property real localY: 0
    property real screenWidth: 0
    property real screenHeight: 0

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.colors.primaryContainer || "#4F378B" }
            GradientStop { position: 1.0; color: root.colors.surface || "#1C1B1F" }
        }
    }

}
