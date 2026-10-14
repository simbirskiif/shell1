import QtQuick
import Quickshell
import Quickshell.Services.Notifications
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

    // Появление: карточка выезжает справа налево.
    NumberAnimation {
        id: enterAnim

        target: root
        property: "enterOffset"
        to: 0
        duration: Theme.motionShort4
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveEmphasizedDecelerate
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
    // сколько карточку сдвинули, и плавно возвращаем смещение к нулю.
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

    NumberAnimation {
        id: shiftAnim

        target: root
        property: "stackShift"
        to: 0
        duration: Theme.motionShort4
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveEmphasizedDecelerate
    }

    Component.onCompleted: root.playEnter()

    // Запустить появление карточки (выезд справа налево).
    function playEnter() {
        if (root.width > 0)
            root.startEnter();
        else
            enterStart.restart();
    }

    // Отпустили пальцы, порог не пройден — сюда возвращает Behavior.
    Behavior on swipeOffset {
        enabled: !root.isSwiping && !root.removing
        NumberAnimation {
            duration: Theme.motionSwipeReturn
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEmphasizedDecelerate
        }
    }

    // Улёт за край: accelerate, 180 мс.
    NumberAnimation {
        id: exitAnim

        target: root
        property: "swipeOffset"
        duration: Theme.motionSwipeExit
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveEmphasizedAccelerate
        onStopped: root.completeRemoval()
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
        radius: Theme.notificationRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: root.critical ? Theme.withAlpha(Theme.lowColor, 0.55) : Theme.quickBorder
        // Плавно тает, пока едет за край.
        opacity: Math.max(0, 1.0 - Math.abs(root.swipeOffset) / (width * 0.85))

        // Клик в любом месте карточки — действие по умолчанию. Кнопки
        // действий и крестик объявлены ниже, поэтому получают клик первыми.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.invokeDefault()
        }

        // Полоска важности: у critical она красная.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.notificationRadius
            anchors.bottomMargin: Theme.notificationRadius
            width: root.critical ? 3 : 0
            radius: width / 2
            color: Theme.lowColor
        }

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.notificationPadding
            spacing: 6

            // Шапка: иконка приложения, имя и крестик.
            Item {
                width: parent.width
                height: 20

                Image {
                    id: appIconImage

                    width: 20
                    height: 20
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.appIconSource !== "" && appIconImage.status !== Image.Error
                    source: root.appIconSource
                    sourceSize: Qt.size(20, 20)
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: appIconGlyph

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !appIconImage.visible
                    text: "\uf0f3"
                    color: Theme.quickTextDim
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 14
                }

                Text {
                    id: appName

                    anchors.left: appIconGlyph.right
                    anchors.leftMargin: 8
                    anchors.right: closeButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.notification && root.notification.appName
                          ? root.notification.appName : ""
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: closeButton

                    width: 20
                    height: 20
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    radius: width / 2
                    color: closeHover.hovered ? Theme.quickTileHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: Theme.quickTextDim
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 11
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

            Text {
                width: parent.width
                visible: text !== ""
                text: root.notification && root.notification.summary
                      ? root.notification.summary : ""
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.notification && root.notification.body
                      ? root.notification.body : ""
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            // Кнопки действий из уведомления.
            Row {
                width: parent.width
                height: 28
                spacing: 6
                visible: root.hasActions

                Repeater {
                    model: root.hasActions ? root.notification.actions : []

                    delegate: Rectangle {
                        id: actionButton

                        required property var modelData

                        width: actionLabel.implicitWidth + 24
                        height: 28
                        radius: height / 2
                        color: actionHover.hovered ? Theme.quickTileHover : Theme.quickTile
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: actionButton.modelData ? actionButton.modelData.text : ""
                            color: Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
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
