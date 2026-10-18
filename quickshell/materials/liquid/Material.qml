import QtQuick

// Liquid glass из qs-glass: размытие, преломление на кромке, хроматическая
// дисперсия и подсветка. Источник — те же обои, что и у glass; все параметры
// задаются в экранных пикселях, чтобы рисунок не зависел от размера карточки.
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

    readonly property bool hasWallpaper: root.wallpaperSource.length > 0
    readonly property color tintColor: root.colors.surface || "#151519"

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

    ShaderEffectSource {
        id: widgetsSample

        sourceItem: root.widgetsBackdrop
        sourceRect: Qt.rect(root.localX, root.localY,
                            Math.max(1, root.width), Math.max(1, root.height))
        hideSource: false
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
        property real refraction: 18
        property real blurRadius: 14
        property real bezel: 24
        property real rim: 0.6
        property color tint: Qt.rgba(root.tintColor.r, root.tintColor.g,
                                     root.tintColor.b, root.dim)
        property variant widgets: widgetsSample
        property real useWidgets: root.widgetsBackdrop !== null ? 1 : 0

        fragmentShader: Qt.resolvedUrl("liquid.frag.qsb")
    }
}
