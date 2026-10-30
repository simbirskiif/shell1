import QtQuick
import ".."
import "../../singletons"

// Карточка дока. Окно под ней имеет постоянный размер и прозрачный фон,
// поэтому здесь можно свободно анимировать и размер, и положение: ни один
// кадр не требует пересоздания поверхности композитором.
//
// Компактная полоса и большая панель — два слоя одной карточки. При
// раскрытии ширина/высота едут Behavior'ами, а содержимое перетекает
// кроссфейдом. Если раскрытие вызвано у скрытого дока, DockState сначала
// доводит появление, и только потом включает expanded — панель не прыгает.
Item {
    id: root

    required property string screenName

    readonly property bool shown: DockState.shown && DockState.screenName === root.screenName
    readonly property bool expanded: root.shown && DockState.expanded

    // Содержимое панели проявляется не в первом кадре роста, а когда
    // карточка уже набрала ширину: иначе сетка приложений на миг
    // показывается в сжатой компактной ширине.
    property bool panelShown: false
    // Сетку приложений не создаём, пока док ни разу не показали: иначе
    // оболочка на старте грузила бы десятки иконок ради скрытой панели.
    property bool panelLoaded: false
    onShownChanged: {
        root.openSwipe = 0;
        if (root.shown)
            root.panelLoaded = true;
    }

    // Накопленная дельта свайпа вверх по компактной полосе.
    property real openSwipe: 0
    onExpandedChanged: {
        panelDelay.stop();
        if (root.expanded)
            panelDelay.restart();
        else
            root.panelShown = false;
    }

    Timer {
        id: panelDelay
        interval: 70
        onTriggered: root.panelShown = root.expanded
    }

    // 0..1 — насколько карточка выехала из-за нижней кромки.
    property real reveal: root.shown ? 1 : 0
    Behavior on reveal {
        MotionNumber {
            duration: Theme.dockRevealDuration
            curve: root.shown ? Theme.curveDockExpressive : Theme.curveDockExit
        }
    }

    // Размеры считаются от содержимого, поэтому полоса подстраивается под
    // число избранных приложений, а панель ограничена экраном.
    readonly property int favoriteCount: DockApps.favorites.length
    readonly property real baseButtonSize: DockSettings.iconSize + 18
    // Ширина ряда без шкалирования; её считает DockCompactRow, чтобы
    // положение кнопки (слева/справа) не дублировало арифметику здесь.
    readonly property real rowBaseWidth: compactRow.implicitWidth
    readonly property real maxCompactWidth: {
        const available = root.parent && root.parent.width > 0
            ? root.parent.width - 24 : Theme.dockMaxWidth;
        return Math.max(280, Math.min(Theme.dockMaxWidth, available));
    }
    // Переполнение: ряд ужимается целиком, пока не влезет в предел ширины.
    // Иконки при этом уменьшаются вместе с промежутками, а не наезжают.
    readonly property real compactFitScale: root.rowBaseWidth <= 0 ? 1
        : Math.max(0.35, Math.min(1,
            (root.maxCompactWidth - Theme.dockPadding * 2) / root.rowBaseWidth))
    readonly property real compactWidth: Math.round(Math.min(root.maxCompactWidth,
        root.rowBaseWidth * root.compactFitScale + Theme.dockPadding * 2))
    // Высокий размер иконок требует чуть более высокой карточки, иначе
    // увеличение при наведении обрезается сверху и снизу.
    readonly property real compactHeight: Math.max(Theme.dockHeight,
                                                   root.baseButtonSize + 14)
    readonly property real panelWidth: Math.max(root.compactWidth + 40,
        Math.min(Theme.dockPanelWidth,
                 root.parent && root.parent.width > 0
                     ? root.parent.width - 24 : Theme.dockPanelWidth))
    readonly property real targetWidth: root.expanded ? root.panelWidth : root.compactWidth
    readonly property real targetHeight: root.expanded
        ? Math.min(Theme.dockPanelHeight,
                   root.parent && root.parent.height > 0
                       ? root.parent.height - Theme.dockBottomMargin - 12
                       : Theme.dockPanelHeight)
        : root.compactHeight

    width: root.targetWidth
    height: root.targetHeight
    opacity: root.reveal
    scale: 0.96 + 0.04 * root.reveal
    transformOrigin: Item.Bottom
    visible: root.reveal > 0.001

    // m3 container transform: размер и радиус меняются вместе. Кривая без
    // overshoot: карточка не должна вылезать за маску ввода.
    Behavior on width {
        MotionNumber {
            duration: Theme.dockMorphDuration
            curve: Theme.curveEmphasizedDecelerate
        }
    }

    Behavior on height {
        MotionNumber {
            duration: Theme.dockMorphDuration
            curve: Theme.curveEmphasizedDecelerate
        }
    }

    property real cardRadius: root.expanded ? Theme.dockPanelRadius : Theme.dockRadius
    Behavior on cardRadius {
        MotionNumber {
            duration: Theme.dockMorphDuration
            curve: Theme.curveEmphasized
        }
    }

    // Сдвиг вниз на высоту карточки: при reveal = 0 она целиком за кромкой.
    transform: Translate {
        y: (1 - root.reveal) * (root.height + Theme.dockBottomMargin + 20)
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cardRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder
        clip: true

        DockCompactRow {
            id: compactRow
            anchors.centerIn: parent
            buttonFirst: DockSettings.buttonOnLeft
            buttonSize: root.baseButtonSize
            iconSize: DockSettings.iconSize
            glyphSize: Math.max(15, Math.round(DockSettings.iconSize * 0.6))
            enabled: !root.expanded
            opacity: root.expanded ? 0 : 1
            // Уход полосы быстрее прихода: панель должна проявиться раньше,
            // чем пустое место успеет броситься в глаза.
            Behavior on opacity {
                MotionNumber {
                    duration: root.expanded ? Theme.dockFadeDuration : Theme.dockMorphDuration
                    curve: Theme.curveEmphasized
                }
            }
            // Два множителя: уход при раскрытии и ужимание при переполнении.
            scale: (root.expanded ? 0.9 : 1) * root.compactFitScale
            Behavior on scale {
                MotionNumber {
                    duration: Theme.dockMorphDuration
                    curve: Theme.curveEmphasized
                }
            }

            onExpandRequested: DockState.expand(root.screenName, false)
        }

        // Свайп вверх по компактной полосе открывает панель. На тачпаде
        // это две пальца (pixelDelta), на тачскрине/мыши — DragHandler.
        // Физический свайп вверх даёт отрицательную дельту прокрутки.
        WheelHandler {
            id: openWheel
            enabled: root.shown && !DockState.expanded
            acceptedDevices: PointerDevice.TouchPad
            orientation: Qt.Vertical

            onWheel: (event) => {
                const dy = event.pixelDelta.y;
                if (dy === 0)
                    return;
                // inverted приходит от natural scrolling: приводим дельту
                // к физическому направлению пальцев, иначе «вверх» зависел
                // бы от системной настройки прокрутки.
                const physical = event.inverted ? -dy : dy;
                root.openSwipe += physical;
                if (root.openSwipe <= -Theme.dockSwipeThreshold) {
                    root.openSwipe = 0;
                    swipeReset.stop();
                    DockState.expand(root.screenName, false);
                } else {
                    swipeReset.restart();
                }
                event.accepted = true;
            }
        }

        DragHandler {
            id: openDrag
            enabled: root.shown && !DockState.expanded
            acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Mouse
            xAxis.enabled: false
            yAxis.enabled: true
            dragThreshold: 10

            property real distance: 0

            onActiveChanged: {
                if (active) {
                    distance = 0;
                    return;
                }
                if (distance <= -Theme.dockSwipeThreshold)
                    DockState.expand(root.screenName, false);
                distance = 0;
            }

            onTranslationChanged: if (active) distance = translation.y
        }

        Timer {
            id: swipeReset
            interval: 180
            onTriggered: root.openSwipe = 0
        }

        Loader {
            id: panelLoader
            anchors.fill: parent
            anchors.margins: Theme.dockPanelPadding
            active: root.panelLoaded
            sourceComponent: panelComponent
            enabled: root.panelShown
            opacity: root.panelShown ? 1 : 0
            visible: opacity > 0.001
            Behavior on opacity {
                MotionNumber {
                    duration: Theme.dockFadeDuration
                    curve: Theme.curveEmphasized
                }
            }
        }
    }

    Component {
        id: panelComponent

        DockPanel {
            screenName: root.screenName

            onCloseRequested: DockState.hide()
        }
    }
}
