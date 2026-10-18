import QtQuick

// solid + процедурный плёночный шум в шейдере (без перерисовки во времени).
Item {
    id: root

    property var colors: ({})
    property real radius: 0
    property real dim: 0.60
    property var size: Qt.size(0, 0)
    property string wallpaperSource: ""
    property bool editing: false
    property real offsetX: 0
    property real offsetY: 0
    property real screenWidth: 0
    property real screenHeight: 0

    ShaderEffect {
        anchors.fill: parent
        blending: true

        property vector2d size: Qt.vector2d(Math.max(1, root.width),
                                            Math.max(1, root.height))
        property real radius: root.radius
        property color surface: root.colors.surface || "#1C1B1F"
        property color outline: root.colors.outline || "#938F99"
        property real strength: 0.10

        fragmentShader: "grain-rounded.frag.qsb"
    }
}
