import QtQuick
import ".."
import Quickshell
import "../../singletons"

// Выпадающая панель быстрых настроек под кнопкой статуса в баре.
// Ширина ограничена темой, высота следует за содержимым с анимацией —
// вместе с кроссфейдом видов это даёт плавное «раскрытие» внутрь.
PopupWindow {
    id: root

    required property PanelWindow anchorWindow

    readonly property string screenName: anchorWindow.screen ? anchorWindow.screen.name : ""

    // Источник правды — UiState. visible выставляем руками, а не биндингом:
    // окно может погасить и сам композитор (grabFocus при клике мимо),
    // тогда мы просто синхронизируем состояние обратно.
    visible: false
    grabFocus: true

    function toggle() {
        UiState.toggle(root.screenName);
    }

    function close() {
        UiState.close();
    }

    function syncVisibility() {
        root.visible = UiState.openedScreen === root.screenName;
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

    // Правый верхний угол попапа — под кнопкой в баре, растёт вниз-влево.
    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width - Theme.barPadding
    anchor.rect.y: anchorWindow.height + 4
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left

    color: "transparent"

    // Панель не должна вылезать за экран: высоту ограничиваем,
    // а содержимое уходит в прокрутку.
    readonly property real maxHeight: anchorWindow.screen ? anchorWindow.screen.height - anchorWindow.height - 16 : 10000

    implicitWidth: panelItem.implicitWidth + Theme.quickPadding * 2
    // Во время жеста окно держит запас по высоте (зафиксированный на старте)
    // и не меняет размер ни на одном кадре — видимую высоту внутри ведёт
    // карточка. В остальное время окно едет за той же целью, что и карточка,
    // своей m3-анимацией: поэтому запас снимается плавно, а не одним
    // прыжком, и контент в конце жеста никуда не дёргается.
    // Окно растёт ещё и под контекстное меню: оно живёт в этом же окне
    // (попап рисуется поверх layer-shell поверхностей) и должно помещаться
    // целиком, иначе карточка обрежется. Запас нужен только пока меню
    // открыто: у закрытого меню высота всё равно посчитана, и окно было бы
    // всегда выше карточки на эту величину — в полосе под ней клик мимо не
    // закрывал бы попап.
    readonly property real menuRoom: Math.max(contextMenu.open ? contextMenu.maxCardHeight : 0,
                                              bluetoothContextMenu.open ? bluetoothContextMenu.maxCardHeight : 0)

    implicitHeight: Math.min((panelItem.gestureSizing
        ? panelItem.gestureRoom
        : panelItem.contentHeight) + Theme.quickPadding * 2, root.maxHeight)
        + root.menuRoom
    // m3 container transform: контейнер меняет размер на emphasized.
    Behavior on implicitWidth {
        MotionNumber {
            duration: Theme.motionMedium2
            curve: Theme.curveEmphasized
        }
    }
    Behavior on implicitHeight {
        // Анимация всегда включена, а цель во время жеста постоянна, поэтому
        // внутри жеста поверхность не меняется. Выключать её нельзя: запись
        // проскакивает мимо ещё выключенного Behavior, и запас снимается
        // одним прыжком — контент от этого и дёргался.
        //
        // Исключение — открытое контекстное меню: его карточка появляется
        // сразу, и при анимированном росте окна её низ (вместе с кнопками
        // подтверждения) успевал обрезаться. Пока меню открыто, высота окна
        // меняется мгновенно.
        enabled: !(contextMenu.open || bluetoothContextMenu.open)
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
        border.width: 1
        border.color: Theme.quickBorder

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
