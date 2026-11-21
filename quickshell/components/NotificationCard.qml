import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "expressive"
import "../singletons"

// Карточка уведомления с горизонтальным смахиванием.
//
// Смахивание работает двумя способами, и это принципиально разные события:
//   * два пальца по тачпаду — Wayland/Qt отдают это горизонтальным
//     WheelEvent, а не drag'ом, поэтому ловим WheelHandler;
//   * зажатая мышь — DragHandler по оси X.
//
// Смещение — одно свойство swipeOffset: во время жеста карточка едет за
// пальцами 1:1 (Behavior выключен), а если порог не пройден — упруго
// возвращается (Behavior включается и играет decelerate).
Item {
    id: root

    required property var notification
    // "popup" — тост: смахивание убирает только его, уведомление остаётся
    // в Центре. "center" — история: смахивание закрывает навсегда.
    property string context: "popup"

    property real swipeOffset: 0
    // Смещение появления: карточка выезжает справа налево.
    property real enterOffset: 0
    // Идёт жест: Behavior выключен, карточка следует за пальцами.
    property bool isSwiping: false
    // Играет анимация улёта: Behavior тоже выключен.
    property bool removing: false
    // Закрыть навсегда, а не просто убрать тост (крестик).
    property bool permanent: false
    property bool finished: false
    // Действие, вызванное кликом по карточке (сработает после улёта тоста).
    property var clickAction: null
    // Позиция в стопке: задаёт задержку каскада при общей очистке.
    property int staggerIndex: 0

    signal removed()

    readonly property var flow: root.notification
    // Сколько держать тост: 0 — «никогда», < 0 — серверное умолчание.
    readonly property real timeout: {
        const item = root.notification;
        if (!item)
            return 0;
        if (item.expireTimeout > 0)
            return item.expireTimeout;
        if (item.expireTimeout === 0)
            return 0;
        return 5;
    }
    readonly property bool critical: root.notification !== null
                                     && root.notification !== undefined
                                     && root.notification.urgency === NotificationUrgency.Critical

    // --- визуальные роли Expressive -----------------------------------------
    // Контейнер крупной карточки: тональная поверхность; критичное
    // уведомление читается контрастным errorContainer, а не полоской-рамкой.
    readonly property color containerColor: root.critical ? Theme.errorContainer
                                                           : Theme.surfaceContainerHigh
    readonly property color inkColor: root.critical ? Theme.scheme.onErrorContainer
                                                    : Theme.scheme.onSurface
    readonly property color subtleInk: root.critical
                                       ? Theme.withAlpha(Theme.scheme.onErrorContainer, 0.78)
                                       : Theme.scheme.onSurfaceVariant
    readonly property color actionAccent: root.critical ? Theme.error : Theme.primary
    readonly property color actionInk: root.critical ? Theme.scheme.onError : Theme.scheme.onPrimary

    // Аватар приложения — морфящаяся форма. Форма и цвет контейнера
    // выводятся из имени приложения, поэтому карточки одного приложения
    // группируются формой и цветом: соседние уведомления различимы
    // боковым зрением, без разделителей и рамок.
    readonly property int avatarTone: {
        const item = root.notification;
        const name = item !== null && item !== undefined && item.appName
                     ? item.appName : "notification";
        let hash = 0;
        for (let i = 0; i < name.length; ++i)
            hash = (hash * 31 + name.charCodeAt(i)) % 3;
        return hash;
    }
    readonly property string avatarShape: root.avatarTone === 0 ? "cookie"
                                        : root.avatarTone === 1 ? "clover"
                                        : "sunny"
    readonly property color avatarContainer: root.critical
                                             ? Theme.error
                                             : root.avatarTone === 0 ? Theme.primaryContainer
                                             : root.avatarTone === 1 ? Theme.tertiaryContainer
                                             : Theme.secondaryContainer
    readonly property color avatarInk: root.critical
                                       ? Theme.scheme.onError
                                       : root.avatarTone === 0 ? Theme.scheme.onPrimaryContainer
                                       : root.avatarTone === 1 ? Theme.scheme.onTertiaryContainer
                                       : Theme.scheme.onSecondaryContainer

    // Картинку показываем только если это настоящий файл (например, аватар
    // из image-data). Иконку темы не тянем: она может числиться в индексе,
    // но не грузиться, и вместо значка получается битая картинка — а в
    // оболочке иконки и так глифы Nerd Font.
    readonly property string appIconSource: {
        const item = root.notification;
        if (!item || item.image === undefined || item.image === "")
            return "";
        const image = item.image;
        if (image.charAt(0) === "/")
            return "file://" + image;
        if (image.indexOf("file://") === 0 || image.indexOf("http") === 0)
            return image;
        return "";
    }
    readonly property bool hasActions: {
        const item = root.notification;
        return item !== null && item !== undefined && item.actions !== undefined
               && item.actions.length > 0;
    }
    // Действие по умолчанию: его вызывает клик в любом месте карточки.
    readonly property var defaultAction: {
        const item = root.notification;
        if (!item || item.actions === undefined)
            return null;
        for (let i = 0; i < item.actions.length; ++i) {
            if (item.actions[i].identifier === "default")
                return item.actions[i];
        }
        return null;
    }

    implicitHeight: card.implicitHeight

    // Появление: карточка выезжает справа налево на spatial-пружине —
    // лёгкий перелёт за левый край и упругий возврат. Логика та же:
    // enterOffset стартует с ширины и доводится до нуля.
    SpringSpatial {
        id: enterAnim

        target: root
        property: "enterOffset"
        to: 0
    }

    // У только что созданного делегата ширина может быть ещё не разрешена,
    // поэтому старт откладываем до раскладки — иначе выезд схлопнется в 0.
    Timer {
        id: enterStart

        interval: 0
        repeat: false
        onTriggered: root.startEnter()
    }

    function startEnter() {
        root.enterOffset = root.width;
        enterAnim.restart();
    }

    // Съезд соседей ведём сами: Column (Positioner) ставит y ребёнка
    // мгновенно, Behavior на y у такого ребёнка не играет. Запоминаем, на
    // сколько карточку сдвинули, и пружиной возвращаем смещение к нулю.
    property real lastY: 0
    property real stackShift: 0
    property bool stackReady: false

    Timer {
        interval: 80
        running: true
        repeat: false
        onTriggered: {
            root.lastY = root.y;
            root.stackReady = true;
        }
    }

    onYChanged: {
        if (!root.stackReady) {
            root.lastY = root.y;
            return;
        }
        root.stackShift += root.lastY - root.y;
        root.lastY = root.y;
        shiftAnim.restart();
    }

    // Возврат стопки на место — spatial-пружина: соседи съезжают упруго.
    SpringSpatial {
        id: shiftAnim

        target: root
        property: "stackShift"
        to: 0
    }

    Component.onCompleted: root.playEnter()

    // Запустить появление карточки (выезд справа налево).
    function playEnter() {
        if (root.width > 0)
            root.startEnter();
        else
            enterStart.restart();
    }

    // Отпустили пальцы, порог не пройден — сюда возвращает Behavior:
    // spatial-пружина упруго возвращает карточку на место.
    Behavior on swipeOffset {
        enabled: !root.isSwiping && !root.removing
        SpringSpatial {}
    }

    // Улёт за край — тоже spatial-пружина. Карточка гаснет уже к 85%
    // ширины, поэтому удаляем её, как только смещение пересекло 90%:
    // момент удаления прежний (карточка уезжает невидимой), но без
    // фиксированной длительности. onStopped — страховка.
    SpringSpatial {
        id: exitAnim

        target: root
        property: "swipeOffset"
        onStopped: root.completeRemoval()
    }

    onSwipeOffsetChanged: {
        if (root.removing && !root.finished && root.width > 0
                && Math.abs(root.swipeOffset) >= root.width * 0.9)
            root.completeRemoval();
    }

    // Задержка перед улётом: нужна каскаду при общей очистке.
    Timer {
        id: exitDelay

        repeat: false
        onTriggered: exitAnim.restart()
    }

    // WheelEvent не всегда присылает финальную фазу: если ScrollEnd не
    // пришёл, считаем жест законченным по паузе.
    Timer {
        id: wheelEndTimer

        interval: 120
        repeat: false
        onTriggered: root.finishSwipe()
    }

    // Тост сам уезжает через expireTimeout: из активных убираем, в истории
    // уведомление остаётся.
    Timer {
        id: expireTimer

        repeat: false
        interval: Math.max(1000, Math.round(root.timeout * 1000))
        running: root.context === "popup" && !root.removing
                 && root.notification !== null && root.notification !== undefined
                 && root.timeout > 0
                 && !root.notification.resident
                 && !root.critical
        onTriggered: root.slideOut(root.width * 1.2, false)
    }

    onIsSwipingChanged: {
        if (root.isSwiping)
            expireTimer.stop();
    }

    // --- завершение жеста ---------------------------------------------------

    // Один шаг жеста двумя пальцами. Вынесено из WheelHandler отдельной
    // функцией, чтобы логика не зависела от того, откуда пришла дельта
    // (pixelDelta тачпада или angleDelta мыши).
    function applyWheelDelta(dx, phase) {
        // Чувствительность из настроек: у разных тачпадов pixelDelta
        // отличается в разы, поэтому дельту умножаем.
        const step = dx * NotificationService.swipeSensitivity;
        if (step !== 0) {
            // Сначала выключаем Behavior, и только потом двигаем: иначе
            // первая же дельта уедет анимацией и часть жеста потеряется.
            root.isSwiping = true;
            root.swipeOffset += step;
            wheelEndTimer.restart();
        }
        // Композитор умеет фазы — не ждём таймер.
        if (phase === Qt.ScrollEnd && root.isSwiping) {
            wheelEndTimer.stop();
            root.finishSwipe();
        }
    }

    // Порог — 20% ширины карточки: смахивать нужно коротким жестом.
    function finishSwipe() {
        if (root.removing || root.finished)
            return;
        root.isSwiping = false;
        if (Math.abs(root.swipeOffset) > root.width * 0.20)
            root.slideOut(root.swipeOffset > 0 ? root.width * 1.2 : -root.width * 1.2, false);
        else
            root.swipeOffset = 0; // Behavior вернёт упруго
    }

    // Крестик: убрать тост и закрыть уведомление навсегда.
    function dismissPermanently() {
        root.permanent = true;
        root.slideOut(root.width * 1.2, false);
    }

    // Клик в любом месте карточки: действие по умолчанию. Если его нет —
    // в Центре закрываем уведомление, тост просто убираем.
    function invokeDefault() {
        const action = root.defaultAction;
        if (root.context === "center") {
            if (action)
                action.invoke();
            else
                root.dismissPermanently();
            return;
        }
        root.clickAction = action;
        root.slideOut(root.width * 1.2, false);
    }

    function slideOut(target, permanent, delay) {
        if (root.removing || root.finished)
            return;
        root.permanent = root.permanent || permanent;
        root.removing = true; // Behavior off, дальше ведёт exitAnim
        exitAnim.to = target;
        if (delay !== undefined && delay > 0) {
            exitDelay.interval = delay;
            exitDelay.restart();
        } else {
            exitAnim.restart();
        }
    }

    function completeRemoval() {
        if (!root.removing || root.finished)
            return;
        root.finished = true;
        // Клик по карточке: сначала действие, потом убираем тост.
        if (root.clickAction) {
            const action = root.clickAction;
            root.clickAction = null;
            if (root.context === "popup")
                NotificationService.dropPopup(root.notification);
            action.invoke();
            root.removed();
            return;
        }
        if (root.context === "center" || root.permanent)
            NotificationService.dismiss(root.notification);   // навсегда
        else
            NotificationService.dropPopup(root.notification); // только тост
        root.removed();
    }

    // Общая очистка: уезжаем каскадом и закрываем уведомления навсегда.
    Connections {
        target: NotificationService

        function onClearRequested() {
            root.slideOut(root.width * 1.2, true, Math.min(root.staggerIndex, 8) * 30);
        }
    }

    // --- жест двумя пальцами по тачпаду -------------------------------------
    //
    // Handler'ы висят на неподвижном корне, а не на уезжающей карточке: если
    // повесить их на саму карточку, она уходит из-под курсора (мышь) или
    // из-под неподвижного пальца (тачпад), и жест обрывается.
    WheelHandler {
        id: wheelHandler

        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse

        onWheel: (event) => {
            // Тачпад в Wayland даёт точные пиксели; angleDelta — фоллбэк
            // для мыши и композиторов без pixelDelta.
            const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x
                                                : event.angleDelta.x * 0.5;
            // Забираем событие, только если жест действительно
            // горизонтальный: иначе вертикальный скролл списка сломается.
            if (dx !== 0)
                event.accepted = true;
            root.applyWheelDelta(dx, event.phase);
        }
    }

    // --- перетаскивание зажатой мышью ----------------------------------------
    DragHandler {
        id: dragHandler

        // Двигаем карточку сами через swipeOffset, а не средствами
        // handler'а: иначе он перебил бы привязку x.
        target: null
        acceptedDevices: PointerDevice.Mouse
        xAxis.enabled: true
        yAxis.enabled: false

        property real baseOffset: 0

        onActiveChanged: {
            if (active) {
                baseOffset = root.swipeOffset;
                root.isSwiping = true;
            } else {
                root.finishSwipe();
            }
        }

        onActiveTranslationChanged: {
            if (active)
                root.swipeOffset = baseOffset + activeTranslation.x;
        }
    }

    // --- карточка -----------------------------------------------------------

    Rectangle {
        id: card

        x: root.swipeOffset + root.enterOffset
        y: root.stackShift
        width: parent.width
        implicitHeight: content.implicitHeight + Theme.notificationPadding * 2
        height: implicitHeight
        // Крупная Expressive-карточка: радиус 32, без обводки и тени.
        // Тональность контейнера несёт важность: critical — errorContainer.
        radius: Theme.notificationRadius
        color: root.containerColor
        // Плавно тает, пока едет за край: к 85% ширины уже невидима.
        opacity: Math.max(0, 1.0 - Math.abs(root.swipeOffset) / (width * 0.85))
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        // Клик в любом месте карточки — действие по умолчанию. Кнопки
        // действий и крестик объявлены ниже, поэтому получают клик первыми.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.invokeDefault()
        }

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.notificationPadding
            spacing: Theme.space.sm

            // Шапка: аватар-орб приложения, имя и крестик.
            Item {
                width: parent.width
                height: 52

                // Аватар: морфящаяся форма вместо квадратной иконки.
                // Форма и цвет выводятся из приложения — список карточек
                // группируется цветом и контуром, а не рамками.
                Item {
                    id: avatar

                    width: 52
                    height: 52
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    MorphShape {
                        anchors.fill: parent
                        shape: root.avatarShape
                        color: root.avatarContainer
                        modulation: 0.9
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                    }

                    Image {
                        id: appIconImage

                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        visible: root.appIconSource !== "" && appIconImage.status !== Image.Error
                        source: root.appIconSource
                        sourceSize: Qt.size(28, 28)
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !appIconImage.visible
                        text: "\uf0f3"
                        color: root.avatarInk
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 24
                    }
                }

                Text {
                    id: appName

                    anchors.left: avatar.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: closeButton.left
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.notification && root.notification.appName
                          ? root.notification.appName : ""
                    // Кто прислал — вспомогательная подпись, M3 labelMedium.
                    color: root.subtleInk
                    font: Theme.typeLabelMedium
                    elide: Text.ElideRight
                }

                // Крестик — крупная круглая тач-цель 44. Наведение
                // подсвечивает форму-«печенье», нажатие сжимает пружиной.
                Item {
                    id: closeButton

                    width: 44
                    height: 44
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    scale: closeHover.pressed ? 0.88 : (closeHover.containsMouse ? 1.06 : 1)
                    Behavior on scale { SpringSpatialFast {} }

                    MorphShape {
                        anchors.fill: parent
                        shape: closeHover.containsMouse ? "cookie" : "circle"
                        modulation: 0.8
                        color: closeHover.containsMouse
                               ? Theme.withAlpha(root.inkColor, 0.10)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: root.subtleInk
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.md
                    }

                    MouseArea {
                        id: closeHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissPermanently()
                    }
                }
            }

            // Заголовок — крупный emphasized-стиль: иерархия читается с
            // расстояния, а не только цветом.
            Text {
                width: parent.width
                visible: text !== ""
                text: root.notification && root.notification.summary
                      ? root.notification.summary : ""
                color: root.inkColor
                font: Theme.typeEmphasizedTitleMedium
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.notification && root.notification.body
                      ? root.notification.body : ""
                color: root.subtleInk
                font: Theme.typeBodyMedium
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            // Действия: крупные пилюли 44. Действие по умолчанию —
            // filled-кнопка акцентного контейнера, остальные — text-кнопки.
            Row {
                width: parent.width
                height: Theme.buttonHeight
                spacing: Theme.space.sm
                visible: root.hasActions

                Repeater {
                    model: root.hasActions ? root.notification.actions : []

                    delegate: Rectangle {
                        id: actionButton

                        required property var modelData

                        readonly property bool filled: actionButton.modelData !== null
                            && actionButton.modelData !== undefined
                            && actionButton.modelData.identifier === "default"

                        width: Math.max(Theme.touchTarget,
                                        actionLabel.implicitWidth + Theme.space.xl)
                        height: Theme.buttonHeight
                        radius: height / 2
                        color: actionButton.filled ? root.actionAccent : "transparent"
                        // Нажатие — пружинное сжатие, наведение — лёгкий рост.
                        scale: actionHover.pressed ? 0.92
                               : (actionHover.containsMouse ? 1.04 : 1)
                        Behavior on scale { SpringSpatialFast {} }
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        // Слой состояния M3: у text-кнопки подсветка на
                        // прозрачном контейнере; filled держится цветом.
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.withAlpha(root.actionAccent, Theme.stateHover)
                            opacity: actionHover.containsMouse && !actionButton.filled ? 1 : 0
                            Behavior on opacity { SpringEffects {} }
                        }

                        Text {
                            id: actionLabel

                            anchors.centerIn: parent
                            text: actionButton.modelData ? actionButton.modelData.text : ""
                            color: actionButton.filled ? root.actionInk : root.actionAccent
                            font: Theme.typeEmphasizedLabelLarge
                        }

                        MouseArea {
                            id: actionHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (actionButton.modelData)
                                    actionButton.modelData.invoke();
                            }
                        }
                    }
                }
            }
        }
    }
}
