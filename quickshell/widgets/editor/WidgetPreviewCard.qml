pragma ComponentBehavior: Bound

import QtQuick
import "../../components/expressive"
import "../../singletons"
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

    // Контейнер карточки — один из трёх акцентов M3, выбранных детерминированно
    // по id виджета: в каталоге соседствуют разные по цвету и форме карточки,
    // а не ряд одинаковых серых плиток.
    readonly property int accentSlot: {
        const id = root.widget ? String(root.widget.id) : ""
        let hash = 0
        for (let i = 0; i < id.length; ++i)
            hash = (hash * 31 + id.charCodeAt(i)) >>> 0
        return hash % 3
    }
    readonly property color baseContainer:
        root.accentSlot === 0 ? Theme.primaryContainer
        : root.accentSlot === 1 ? Theme.tertiaryContainer
        : Theme.secondaryContainer
    readonly property color baseInk:
        root.accentSlot === 0 ? Theme.scheme.onPrimaryContainer
        : root.accentSlot === 1 ? Theme.scheme.onTertiaryContainer
        : Theme.scheme.onSecondaryContainer
    readonly property bool hovered: mouse.containsMouse

    // Выразительный контейнер: волна «печенья» в покое, clover при наведении,
    // squircle при перетаскивании — состояние читается формой.
    opacity: root.dragging ? 0.5 : 1
    Behavior on opacity { SpringEffects {} }

    scale: mouse.pressed ? 0.95 : (root.hovered ? 1.03 : 1)
    Behavior on scale { SpringSpatial {} }

    MorphShape {
        anchors.fill: parent
        shape: root.dragging ? "squircle"
             : root.hovered ? "clover"
             : "cookie"
        modulation: 0.42
        color: root.hovered ? Theme.primaryContainer : root.baseContainer
        borderWidth: 0
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // Тёмная подложка под живым превью: контент виджета почти всегда
    // рассчитан на тональную поверхность, а не на яркий контейнер.
    Rectangle {
        id: stagePlate

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.space.sm
        width: Math.min(parent.width - Theme.space.sm * 2, 138)
        height: 64
        radius: Theme.shape.md
        color: Theme.withAlpha(Theme.surface, 0.55)
    }

    Item {
        id: stage

        width: root.contentWidth
        height: root.contentHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.space.sm
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
        anchors.leftMargin: Theme.space.md
        anchors.rightMargin: Theme.space.md
        anchors.bottomMargin: Theme.space.sm
        color: root.hovered ? Theme.scheme.onPrimaryContainer : root.baseInk
        font: Theme.typeEmphasizedLabelLarge
        elide: Text.ElideRight
        text: root.widget ? root.widget.name : ""
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        anchors.centerIn: stage
        visible: previewLoader.status === Loader.Error
        color: Theme.error
        font: Theme.typeBodySmall
        text: "Ошибка превью"
    }

    WidgetContext {
        id: previewContext

        settingsData: root.defaultSettings()
        colorsData: Theme.colorsFor(root.previewColorMode)
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

    readonly property string previewColorMode:
        Config.defaultColorMode === "neutral" ? "neutral" : "accent"

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
            if (!mouse.pressed)
                return
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
