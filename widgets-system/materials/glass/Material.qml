import QtQuick
import QtQuick.Effects

// Полупрозрачное стекло: снимок обоев под карточкой размывается MultiEffect,
// сверху — тонировка surface и светлая рамка. Если обои неизвестны, работает
// как тонированная подложка.
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

    // Кусок обоев, соответствующий положению карточки на экране.
    Item {
        id: wallpaperClip

        anchors.fill: parent
        clip: true
        visible: root.wallpaperSource.length > 0

        Image {
            x: -root.offsetX
            y: -root.offsetY
            width: Math.max(1, root.screenWidth)
            height: Math.max(1, root.screenHeight)
            source: root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
        }
    }

    // Маска со скруглением для размытого слоя.
    Rectangle {
        id: roundedMask

        anchors.fill: parent
        radius: root.radius
        color: "black"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaperClip
        visible: root.wallpaperSource.length > 0
        blurEnabled: true
        blur: 0.55
        blurMax: 32
        maskEnabled: true
        maskSource: roundedMask
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.colors.surface || "#1C1B1F"
        opacity: root.wallpaperSource.length > 0 ? 0.32 : 0.88
    }

    // Лёгкий верхний блик.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.13) }
            GradientStop { position: 0.45; color: "transparent" }
        }
        opacity: 0.8
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.colors.outline || "#938F99"
        opacity: 0.55
    }
}
