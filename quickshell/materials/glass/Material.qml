import QtQuick

// Полупрозрачное стекло: шейдер samplит снимок обоев, размывает его,
// добавляет тонировку, верхний блик и рамку. Если обои неизвестны,
// работает как тонированная подложка.
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

    readonly property bool hasWallpaper: root.wallpaperSource.length > 0
    readonly property real blurPx: Math.max(2, Math.min(root.width, root.height) * 0.07)

    Image {
        id: wallpaper

        width: Math.max(1, root.screenWidth)
        height: Math.max(1, root.screenHeight)
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        visible: root.hasWallpaper
    }

    ShaderEffectSource {
        id: wallpaperSample

        sourceItem: wallpaper
        sourceRect: Qt.rect(root.offsetX, root.offsetY,
                            Math.max(1, root.width), Math.max(1, root.height))
        hideSource: true
        live: true
        recursive: false
    }

    ShaderEffect {
        anchors.fill: parent
        blending: true

        property variant source: wallpaperSample
        property vector2d size: Qt.vector2d(Math.max(1, root.width),
                                            Math.max(1, root.height))
        property real radius: root.radius
        property color tint: root.colors.surface || "#1C1B1F"
        property color outline: root.colors.outline || "#938F99"
        property real tintOpacity: root.hasWallpaper ? 0.32 : 0.90
        property real blur: root.blurPx

        fragmentShader: "glass.frag.qsb"
    }
}
