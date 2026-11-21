import QtQuick
import Quickshell
import Quickshell.Wayland
import "quick"
import "../singletons"

// Диалог запроса BlueZ-агента: PIN, passkey, подтверждение сопряжения.
//
// Отдельная поверхность на весь экран, как у PasswordDialog: попап быстрого
// меню не может забрать клавиатурный фокус (Quickshell падает при
// keyboardFocus на PopupWindow), а PanelWindow — может. Без этого вводить PIN
// физически некуда: helper ждёт agent_reply 30 секунд и затем отклоняет запрос,
// из-за чего сопряжение выглядело зависанием с последующим отказом.
//
// Окно открывается само по BluetoothBackend.agentRequest: запрос приходит
// асинхронно (например, через несколько секунд после начала спаривания).
PanelWindow {
    id: root

    required property ShellScreen dialogScreen

    readonly property string screenName: root.dialogScreen ? root.dialogScreen.name : ""
    // Текущий запрос агента: null — окно закрыто.
    readonly property var request: BluetoothBackend.agentRequest
    readonly property string requestName: request ? String(request.request || "") : ""
    readonly property string kind: request ? String(request.kind || "") : ""
    // Нужен ввод с клавиатуры: PIN или passkey.
    readonly property bool needsInput: requestName === "RequestPinCode"
            || requestName === "RequestPasskey"
    // Нужно подтвердить: показанный на устройстве код либо авторизация.
    readonly property bool needsConfirm: requestName === "RequestConfirmation"
            || requestName === "RequestAuthorization"
            || requestName === "AuthorizeService"
    // Только показать код (ответ BlueZ не ждёт).
    readonly property bool informational: requestName === "DisplayPasskey"
            || requestName === "DisplayPinCode"
    // Код, который нужно показать (passkey или PIN).
    readonly property string displayCode: {
        if (request === null)
            return "";
        if (request.passkey !== undefined && request.passkey !== null)
            return String(request.passkey);
        if (request.pincode !== undefined && request.pincode !== null)
            return String(request.pincode);
        return "";
    }
    readonly property string deviceName: {
        if (request === null)
            return "";
        const found = BluetoothBackend.deviceByAddress(request.address);
        if (found !== null)
            return found.name;
        return String(request.address || "");
    }
    readonly property string title: {
        if (root.informational)
            return "Код сопряжения";
        if (root.needsInput)
            return root.kind === "passkey" ? "Введите passkey" : "Введите PIN";
        return "Подтвердите сопряжение";
    }
    readonly property string subtitle: {
        if (root.informational)
            return root.deviceName;
        if (root.needsInput)
            return root.deviceName + " запрашивает код";
        if (root.requestName === "RequestConfirmation")
            return "Совпадает ли код на " + root.deviceName + "?";
        return "Разрешить подключение к " + root.deviceName + "?";
    }

    screen: dialogScreen
    visible: root.request !== null
             && (UiState.dialogScreen === "" || UiState.dialogScreen === root.screenName)

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bluetooth-pin"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // При открытии сразу ставим фокус в поле: пользователь должен успеть
    // ввести код, пока BlueZ не отвалился по таймауту.
    onVisibleChanged: {
        if (visible) {
            // Появление — явной анимацией с заданными from/to. Behavior по
            // visible мог остаться на промежуточном значении: поверхность
            // создаётся асинхронно, и анимация стартовала до её готовности.
            showFade.restart();
            cardIn.restart();
            if (root.needsInput) {
                pinInput.text = "";
                pinInput.forceActiveFocus();
            }
        } else {
            backdrop.opacity = 0;
        }
    }

    // Отправить ответ и закрыть окно.
    function accept(value) {
        if (root.request === null)
            return;
        BluetoothBackend.replyAgent(true, value === undefined ? "" : value);
    }

    function reject() {
        if (root.request === null)
            return;
        BluetoothBackend.replyAgent(false, "");
    }

    // Затемнение фона — ролью scrim.
    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Theme.scrimOverlay
        opacity: 0

        NumberAnimation {
            id: showFade

            target: backdrop
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.motionShort4
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandardDecelerate
        }

        // Клик мимо карточки — отказ от сопряжения (BlueZ получит Rejected).
        MouseArea {
            anchors.fill: parent
            onClicked: root.reject()
        }

        // Карточка диалога: surface-container-high и радиус shape.xl.
        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(340, parent.width - 32)
            height: column.implicitHeight + Theme.space.xl * 2
            scale: 1
            radius: Theme.shape.xl
            color: Theme.surfaceContainerHigh

            // Клики по карточке не должны её закрывать.
            MouseArea {
                anchors.fill: parent
            }

            NumberAnimation {
                id: cardIn

                target: card
                property: "scale"
                from: Theme.motionFadeThroughScale
                to: 1
                duration: Theme.motionShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }

            Column {
                id: column

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space.xl
                spacing: Theme.space.md

                Text {
                    width: parent.width
                    text: root.title
                    color: Theme.scheme.onSurface
                    font: Theme.typeHeadlineSmall
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: root.subtitle
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                // Код, который нужно сверить или продиктовать. Крупный —
                // headlineSmall (тот же уровень, что заголовок диалога),
                // для поля ввода — titleLarge.
                Text {
                    width: parent.width
                    visible: root.displayCode !== ""
                    text: root.displayCode
                    color: Theme.primary
                    font: root.informational ? Theme.typeHeadlineSmall : Theme.typeTitleLarge
                    horizontalAlignment: Text.AlignHCenter
                }

                // Поле ввода PIN/passkey M3: surface-container-highest,
                // shape.xs, обводка outline / primary в фокусе.
                Rectangle {
                    width: parent.width
                    height: root.needsInput ? Theme.listItemHeight : 0
                    visible: root.needsInput
                    radius: Theme.shape.xs
                    color: Theme.surfaceContainerHighest
                    border.width: pinInput.activeFocus ? 2 : 1
                    border.color: pinInput.activeFocus ? Theme.primary : Theme.outline
                    Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                    TextInput {
                        id: pinInput

                        anchors.fill: parent
                        anchors.leftMargin: Theme.space.lg
                        anchors.rightMargin: Theme.space.lg
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        // PIN устройства бывает и буквенно-цифровым, passkey — только цифры.
                        inputMethodHints: root.kind === "passkey"
                                ? Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                                : Qt.ImhNoPredictiveText
                        color: Theme.scheme.onSurface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.scheme.onPrimary
                        font: Theme.typeBodyLarge
                        onAccepted: root.accept(pinInput.text)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: pinInput.text === "" && !pinInput.activeFocus
                        text: root.kind === "passkey" ? "000000" : "PIN"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodySmall
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.space.sm
                    layoutDirection: Qt.RightToLeft

                    DialogButton {
                        text: root.informational ? "Готово" : "Подтвердить"
                        primary: true
                        enabled: !root.needsInput || pinInput.text !== ""
                        onTriggered: {
                            if (root.informational) {
                                // BlueZ ответа не ждёт: просто закрываем окно.
                                BluetoothBackend.agentRequest = null;
                                return;
                            }
                            root.accept(pinInput.text);
                        }
                    }

                    DialogButton {
                        visible: !root.informational
                        text: "Отмена"
                        onTriggered: root.reject()
                    }
                }
            }
        }
    }

    component DialogButton: Rectangle {
        id: button

        property string text: ""
        property bool primary: false

        signal triggered()

        // M3-кнопки: залитая primary/on-primary и текстовая с подписью
        // primary; недоступная — 12 %/38 % on-surface.
        readonly property color containerColor: {
            if (!button.primary)
                return "transparent";
            if (!button.enabled)
                return Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContainer);
            return Theme.primary;
        }
        readonly property color labelColor: {
            if (!button.enabled)
                return Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContent);
            return button.primary ? Theme.scheme.onPrimary : Theme.primary;
        }

        width: label.implicitWidth + Theme.space.xl * 2
        height: Theme.buttonHeight
        radius: Theme.shape.full
        color: button.containerColor

        // Слой состояния: наведение поверх контейнера.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: button.primary ? Theme.scheme.onPrimary : Theme.primary
            opacity: buttonHover.containsMouse && button.enabled ? Theme.stateHover : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.labelColor
            font: Theme.typeLabelLarge
        }

        MouseArea {
            id: buttonHover
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
