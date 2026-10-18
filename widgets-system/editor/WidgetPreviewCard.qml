pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// Карточка каталога с живым превью (раздел 8.5 ТЗ).
// Контент рендерится в настоящем размере default-сетки и масштабируется в
// карточку; ctx.preview = true, сеть/диск виджет не трогает.
Item {
    id: root

    required property var widget
    required property var metrics
    property string screenName: ""

    signal addRequested()
    signal dragStarted(var point)
    signal dragMoved(var point)
    signal dragFinished()

    readonly property var defaultSize: root.widget && root.widget.sizeSpec
                                     ? root.widget.sizeSpec.defaultSize
                                     : ({ cols: 1, rows: 1 })
    readonly property real contentWidth:
        root.metrics.pixelWidth(root.defaultSize.cols)
    readonly property real contentHeight:
        root.metrics.pixelHeight(root.defaultSize.rows)
    readonly property real previewScale: Math.min(
        1,
        Math.max(0.1, (root.width - 12) / Math.max(1, root.contentWidth)),
        Math.max(0.1, 62 / Math.max(1, root.contentHeight)))

    property bool dragging: false
    property real pressX: 0
    property real pressY: 0

    width: 150
    height: 108

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.colors.surface
        border.width: 1
        border.color: mouse.containsMouse ? Theme.colors.primary : Theme.colors.outline
        opacity: root.dragging ? 0.5 : 1
    }

    Item {
        id: stage

        width: root.contentWidth
        height: root.contentHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        scale: root.previewScale
        transformOrigin: Item.Top

        Loader {
            id: previewLoader

            anchors.fill: parent
            asynchronous: true
            visible: status === Loader.Ready
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        color: Theme.colors.onSurface
        font.pixelSize: 11
        elide: Text.ElideRight
        text: root.widget ? root.widget.name : ""
    }

    Text {
        anchors.centerIn: stage
        visible: previewLoader.status === Loader.Error
        color: Theme.colors.error
        font.pixelSize: 10
        text: "Ошибка превью"
    }

    WidgetContext {
        id: previewContext

        settingsData: root.defaultSettings()
        colorsData: Theme.colorsFor(root.previewColorMode, root.widget)
        rows: root.defaultSize.rows
        cols: root.defaultSize.cols
        width: root.contentWidth
        height: root.contentHeight
        cell: root.metrics.cell
        dp: root.metrics.dp
        colorMode: root.previewColorMode
        material: Config.defaultMaterial
        editing: false
        preview: true
        screen: root.screenName
    }

    readonly property string previewColorMode: {
        if (!root.widget || !root.widget.colorModes || root.widget.colorModes.length === 0)
            return "accent"
        return root.widget.colorModes.indexOf(Config.defaultColorMode) >= 0
             ? Config.defaultColorMode : root.widget.colorModes[0]
    }

    function defaultSettings(): var {
        const values = ({})
        if (!root.widget || !root.widget.settingsSchema)
            return values
        for (const setting of root.widget.settingsSchema)
            values[setting.key] = setting.default
        return values
    }

    Component.onCompleted: {
        if (root.widget) {
            previewLoader.setSource(root.widget.entryUrl + "?preview=1",
                                    { ctx: previewContext })
        }
    }

    onWidgetChanged: {
        if (root.widget)
            previewLoader.setSource(root.widget.entryUrl + "?preview=1",
                                    { ctx: previewContext })
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: true

        onPressed: (event) => {
            root.pressX = event.x
            root.pressY = event.y
            root.dragging = false
        }

        onPositionChanged: (event) => {
            const dx = event.x - root.pressX
            const dy = event.y - root.pressY
            if (!root.dragging && dx * dx + dy * dy >= 36) {
                root.dragging = true
                root.dragStarted(mouse.mapToItem(null, event.x, event.y))
            }
            if (root.dragging)
                root.dragMoved(mouse.mapToItem(null, event.x, event.y))
        }

        onReleased: (event) => {
            if (root.dragging) {
                root.dragging = false
                root.dragFinished()
            } else {
                root.addRequested()
            }
        }

        onCanceled: {
            if (root.dragging) {
                root.dragging = false
                root.dragFinished()
            }
        }
    }
}
