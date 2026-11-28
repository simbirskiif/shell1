import QtQuick
import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../singletons"

// Выпадающая панель быстрых настроек под кнопкой статуса в баре.
// Ширина ограничена темой, высота следует за содержимым с анимацией —
// вместе с кроссфейдом видов это даёт плавное «раскрытие» внутрь.
//
// Это отдельная layer-поверхность, а не PopupWindow: только так можно
// запросить у композитора blur фона через ext-background-effect-v1
// (PopupWindow — xdg-popup, и Hyprland не применяет к нему background
// effect). Геометрия та же: правый верхний угол под баром.
PanelWindow {
    id: root

    required property PanelWindow anchorWindow

    readonly property string screenName: anchorWindow.screen ? anchorWindow.screen.name : ""

    // Источник правды — UiState. visible выставляем руками, чтобы окно
    // успело проявиться/исчезнуть по анимации карточки.
    visible: false

    // Время последнего снятия focus-grab. Клик по кнопке статуса уже
    // закрыл панель через onCleared; этот же клик не должен открыть её
    // заново.
    property double grabClearedAt: 0

    function toggle() {
        if (Date.now() - root.grabClearedAt < 150)
            return;
        UiState.toggle(root.screenName);
    }

    function close() {
        UiState.close();
    }

    function syncVisibility() {
        root.visible = UiState.openedScreen === root.screenName;
        // Поверхность попапа имеет постоянный размер (см. implicitHeight),
        // поэтому при открытии ничего пересчитывать не нужно.
    }

    onVisibleChanged: {
        if (!root.visible && UiState.openedScreen === root.screenName)
            UiState.close();
    }

    Connections {
        target: UiState

        function onOpenedScreenChanged() {
            root.syncVisibility();
        }
    }

    Component.onCompleted: {
        root.syncVisibility();
        UiState.popupHeight = card.height;
    }

    Connections {
        target: card

        // Публикуем видимую высоту (высоту карточки) — видно из
        // `qs ipc call bar state`. Высота окна во время жеста постоянна,
        // поэтому по ней прогресс не отследить.
        function onHeightChanged() {
            UiState.popupHeight = card.height;
        }
    }

    // Правый верхний угол панели — под кнопкой в баре, растёт вниз-влево.
    screen: anchorWindow.screen
    anchors {
        top: true
        right: true
    }
    margins {
        top: anchorWindow.height + 4
        right: Theme.barPadding
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-quick"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive
                                              : WlrKeyboardFocus.None
    WlrLayershell.focusable: root.visible

    // Фон под карточкой размывает композитор; регион — сама карточка,
    // чтобы прозрачная полоса под ней не размывала экран.
    BackgroundEffect.blurRegion: Region {
        item: card
        radius: Theme.quickRadius
    }

    // Клик мимо панели закрывает её. Раньше это делал grabFocus попапа;
    // у layer-поверхности для этого есть focus-grab Hyprland.
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible && !UiState.swipeActive
        onCleared: {
            root.grabClearedAt = Date.now();
            root.close();
        }
    }

    // Панель не должна вылезать за экран: высоту ограничиваем,
    // а содержимое уходит в прокрутку.
    readonly property real maxHeight: anchorWindow.screen ? anchorWindow.screen.height - anchorWindow.height - 16 : 10000

    implicitWidth: panelItem.implicitWidth + Theme.quickPadding * 2

    // Высота поверхности постоянна: весь экран под баром. Раньше окно
    // догоняло карточку шагами (рост сразу, сжатие по таймеру через 360 мс).
    // На Wayland каждый такой шаг — новая поверхность и пересборка буфера
    // в композиторе, а сжатие приходилось на произвольный момент после
    // анимации: панель в этот момент дёргалась. Теперь поверхность не меняет
    // размер, пока попап открыт: карточка анимируется внутри неё, как в
    // NotificationPopups, а прозрачная полоса под карточкой только ловит
    // клик мимо. Поэтому поверхность создаётся сразу нужного размера и больше
    // не пересобирается до закрытия попапа.
    implicitHeight: root.maxHeight

    // Клик по прозрачной полосе под карточкой закрывает попап (как клик мимо).
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }
    // m3 container transform: контейнер меняет размер на emphasized.
    Behavior on implicitWidth {
        MotionNumber {
            duration: Theme.motionMedium2
            curve: Theme.curveEmphasized
        }
    }

    Rectangle {
        id: card
        // Только сверху: во время жеста окно выше карточки, и низ карточки
        // едет сам — обычной перерисовкой сцены, без ресайза поверхности.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(panelItem.contentHeight + Theme.quickPadding * 2, root.maxHeight)
        // Высота едет за сменой панели, а во время жеста — за пальцем.
        Behavior on height {
            // Во время жеста высоту ведёт палец — без сглаживания, иначе
            // карточка отстаёт от контента. В остальное время это m3-анимация
            // раскрытия панели.
            enabled: !UiState.swipeActive
            MotionNumber {
                duration: Theme.motionMedium2
                curve: Theme.curveEmphasized
            }
        }
        clip: true
        radius: Theme.quickRadius
        color: Theme.quickBackground

        // Клики по пустому месту карточки не должны доходить до подложки
        // (она закрывает попап): карточка — не «клик мимо».
        MouseArea {
            anchors.fill: parent
        }

        // Появление: лёгкий рост из угла кнопки.
        // m3 enter: проявление с 92% и ростом из угла кнопки.
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : Theme.motionFadeThroughScale
        transformOrigin: Item.TopRight
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasizedDecelerate
            }
        }
        Behavior on scale {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasizedDecelerate
            }
        }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: Theme.quickPadding
            contentWidth: width
            contentHeight: panelItem.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            QuickPanel {
                id: panelItem
                width: scroller.width
                screenName: root.screenName

                onSettingsRequested: {
                    UiState.close();
                    SettingsWindowState.show("bar", root.screenName);
                }
            }
        }
    }

    // Контекстное меню сети (правый клик по сохранённой сети). Лежит поверх
    // карточки, потому что объявлено после неё.
    NetworkContextMenu {
        id: contextMenu
        width: parent.width
        height: root.implicitHeight
        y: card.height + 4
    }

    // Контекстное меню Bluetooth-устройства (правый клик по строке).
    BluetoothContextMenu {
        id: bluetoothContextMenu
        width: parent.width
        height: root.implicitHeight
        y: card.height + 4
    }
}
