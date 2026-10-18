import QtQuick

// Полупрозрачное стекло: шейдер samplит снимок обоев, размывает его и
// добавляет тонировку и верхний блик. Если обои неизвестны, работает как
// тонированная подложка.
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
    // Размытие задаётся в экранных пикселях и не зависит от размера виджета:
    // иначе рисунок обоев выглядит крупнее на большой карточке и мельче на
    // маленькой.
    readonly property real blurPx: 14

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
        property color tint: root.colors.surface || "#1C1B1F"
        property color outline: root.colors.outline || "#938F99"
        // Плотность тонировки близка к панелям оболочки: обои остаются
        // лёгким оттенком, а не превращают карточку в отдельное стекло.
        property real tintOpacity: root.hasWallpaper ? root.dim
                                                   : Math.min(0.98, root.dim + 0.34)
        property real blur: root.blurPx
        property variant widgets: widgetsSample
        property real useWidgets: root.widgetsBackdrop !== null ? 1 : 0

        fragmentShader: "glass-prism.frag.qsb"
    }
}
