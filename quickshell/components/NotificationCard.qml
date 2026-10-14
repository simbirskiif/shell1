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
    // Идёт жест: Behavior выключен, карточка следует за пальцами.
    property bool isSwiping: false
    // Играет анимация улёта: Behavior тоже выключен.
    property bool removing: false
    // Закрыть навсегда, а не просто убрать тост (крестик).
    property bool permanent: false
    property bool finished: false

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
    readonly property string appIconSource: {
        const item = root.notification;
        if (!item)
            return "";
        if (item.image !== undefined && item.image !== "")
            return item.image.charAt(0) === "/" ? "file://" + item.image : item.image;
        const name = item.appIcon !== undefined ? item.appIcon : "";
        if (name === "")
            return "";
        if (name.charAt(0) === "/")
            return "file://" + name;
        return Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
    }
    readonly property bool hasActions: {
        const item = root.notification;
        return item !== null && item !== undefined && item.actions !== undefined
               && item.actions.length > 0;
    }

    implicitHeight: card.implicitHeight

    // Вход карточки: лёгкий scale-in в духе M3 Expressive.
    NumberAnimation {
        id: enterAnim

        target: card
        property: "scale"
        from: Theme.motionFadeThroughScale
        to: 1
        duration: Theme.motionMedium1
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveEmphasizedDecelerate
    }

    Component.onCompleted: enterAnim.restart()

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
        if (dx !== 0) {
            // Сначала выключаем Behavior, и только потом двигаем: иначе
            // первая же дельта уедет анимацией и часть жеста потеряется.
            root.isSwiping = true;
            root.swipeOffset += dx;
            wheelEndTimer.restart();
        }
        // Композитор умеет фазы — не ждём таймер.
        if (phase === Qt.ScrollEnd && root.isSwiping) {
            wheelEndTimer.stop();
            root.finishSwipe();
        }
    }

    // Порог — 35% ширины карточки.
    function finishSwipe() {
        if (root.removing || root.finished)
            return;
        root.isSwiping = false;
        if (Math.abs(root.swipeOffset) > root.width * 0.35)
            root.slideOut(root.swipeOffset > 0 ? root.width * 1.2 : -root.width * 1.2, false);
        else
            root.swipeOffset = 0; // Behavior вернёт упруго
    }

    // Крестик: убрать тост и закрыть уведомление навсегда.
    function dismissPermanently() {
        root.permanent = true;
        root.slideOut(root.width * 1.2, false);
    }

    function slideOut(target, permanent) {
        if (root.removing || root.finished)
            return;
        root.permanent = root.permanent || permanent;
        root.removing = true; // Behavior off, дальше ведёт exitAnim
        exitAnim.to = target;
        exitAnim.restart();
    }

    function completeRemoval() {
        if (!root.removing || root.finished)
            return;
        root.finished = true;
        if (root.context === "center" || root.permanent)
            NotificationService.dismiss(root.notification);   // навсегда
        else
            NotificationService.dropPopup(root.notification); // только тост
        root.removed();
    }

    // --- карточка -----------------------------------------------------------

    Rectangle {
        id: card

        x: root.swipeOffset
        width: parent.width
        implicitHeight: content.implicitHeight + Theme.notificationPadding * 2
        height: implicitHeight
        radius: Theme.notificationRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: root.critical ? Theme.withAlpha(Theme.lowColor, 0.55) : Theme.quickBorder
        // Плавно тает, пока едет за край.
        opacity: Math.max(0, 1.0 - Math.abs(root.swipeOffset) / (width * 0.85))

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

        // --- свайп двумя пальцами по тачпаду --------------------------------
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

        // --- перетаскивание зажатой мышью ------------------------------------
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
