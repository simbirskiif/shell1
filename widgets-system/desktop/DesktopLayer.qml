import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Слой рабочего стола на одном экране (раздел 2 ТЗ).
//
// Окно занимает доступную область экрана и живёт на слое Bottom: над обоями,
// под обычными окнами. В обычном режиме клавиатурный фокус не берётся, а
// область ввода строится по видимым виджетам. Пока виджетов нет, маска
// пустая — клики проходят в окна под слоем.
//
// Экземпляр создаётся из shell.qml через Variants по Quickshell.screens.
PanelWindow {
    id: root

    readonly property bool debugGrid: Config.showGrid

    visible: true
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Слой не резервирует место (exclusiveZone 0), но exclusionMode Normal
    // оставляет поверхность в свободной от чужих панелей области: композитор
    // сам сдвигает её ниже бара, а GridMetrics считает сетку по фактическому
    // размеру окна.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell:widgets-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.focusable: false

    // Пустая область ввода. В следующих этапах сюда попадут прямоугольники
    // видимых виджетов, а в режиме редактирования — весь экран.
    mask: Region {}

    GridMetrics {
        id: gridMetrics
        screen: root.screen
        windowWidth: root.width
        windowHeight: root.height
    }

    GridOverlay {
        anchors.fill: parent
        visible: root.debugGrid
        metrics: gridMetrics
    }

    Component.onCompleted: {
        console.info("[widgets/layer] desktop layer created for " + gridMetrics.screenName)
    }
}
