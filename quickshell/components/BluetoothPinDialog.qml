import QtQuick
import Quickshell
import Quickshell.Wayland
import "expressive"
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
//
// Оформление — Material 3 Expressive: карточка радиуса 32, морфящийся
// орб-акцент по сценарию (cookie / sunny / clover), крупный код на цветной
// пилюле, высокое поле-пилюля и залитая кнопка на пружине.
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

        SpringEffects {
            id: showFade

            target: backdrop
            property: "opacity"
            to: 1
        }

        // Клик мимо карточки — отказ от сопряжения (BlueZ получит Rejected).
        MouseArea {
            anchors.fill: parent
            onClicked: root.reject()
        }

        // Карточка диалога: surface-container-high и крупный радиус 32.
        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(360, parent.width - 32)
            height: column.implicitHeight + Theme.space.xl * 2
            scale: 1
            radius: Theme.shape.xlIncreased
            color: Theme.surfaceContainerHigh

            // Клики по карточке не должны её закрывать.
            MouseArea {
                anchors.fill: parent
            }

            SpringSpatial {
                id: cardIn

                target: card
                property: "scale"
                from: Theme.motionFadeThroughScale
                to: 1
            }

            Column {
                id: column

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space.xl
                spacing: Theme.space.lg

                // Шапка: крупный морфящийся орб-акцент по сценарию запроса
                // и текст запроса под ним.
                Item {
                    width: parent.width
                    implicitHeight: headerColumn.implicitHeight

                    MorphShape {
                        id: accentOrb

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: Theme.touchTarget + Theme.space.md
                        height: width
                        // Сценарий читается формой: показ кода — sunny,
                        // подтверждение — clover, ввод — cookie.
                        shape: root.informational ? "sunny"
                             : root.needsConfirm ? "clover"
                             : "cookie"
                        color: Theme.primaryContainer

                        Text {
                            anchors.centerIn: parent
                            text: "\uf293"
                            color: Theme.scheme.onPrimaryContainer
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.lg + Theme.space.xs
                        }
                    }

                    Column {
                        id: headerColumn

                        anchors.top: accentOrb.bottom
                        anchors.topMargin: Theme.space.md
                        width: parent.width
                        spacing: Theme.space.xs

                        Text {
                            width: parent.width
                            text: root.title
                            color: Theme.scheme.onSurface
                            font: Theme.typeEmphasizedHeadlineSmall
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: root.subtitle
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodyMedium
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Код, который нужно сверить или продиктовать: крупная
                // цветная пилюля, а не просто строка текста.
                Item {
                    width: parent.width
                    height: codeShape.height
                    visible: root.displayCode !== ""

                    MorphShape {
                        id: codeShape

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: codeText.implicitWidth + Theme.space.xxl * 2
                        height: Theme.touchTarget + Theme.space.md
                        shape: "pill"
                        color: Theme.primaryContainer

                        Text {
                            id: codeText

                            anchors.centerIn: parent
                            text: root.displayCode
                            color: Theme.scheme.onPrimaryContainer
                            // Показ кода — самый крупный акцент окна,
                            // ввод — заметно, но компактнее.
                            font: root.informational ? Theme.typeEmphasizedDisplaySmall
                                                     : Theme.typeEmphasizedTitleLarge
                        }
                    }
                }

                // Поле ввода PIN/passkey Expressive: высокий контейнер-пилюля
                // (56) с толстой обводкой primary.
                Rectangle {
                    width: parent.width
                    height: root.needsInput ? Theme.listItemHeight : 0
                    visible: root.needsInput
                    radius: Theme.shape.full
                    color: Theme.surfaceContainerHighest
                    border.width: pinInput.activeFocus ? 4 : 3
                    border.color: Theme.primary
                    Behavior on border.width { SpringSpatialFast {} }

                    TextInput {
                        id: pinInput

                        anchors.fill: parent
                        anchors.leftMargin: Theme.space.xl
                        anchors.rightMargin: Theme.space.xl
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        // PIN устройства бывает и буквенно-цифровым, passkey — только цифры.
                        inputMethodHints: root.kind === "passkey"
                                ? Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                                : Qt.ImhNoPredictiveText
                        color: Theme.scheme.onSurface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.scheme.onPrimary
                        font: Theme.typeEmphasizedTitleLarge
                        onAccepted: root.accept(pinInput.text)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: pinInput.text === "" && !pinInput.activeFocus
                        text: root.kind === "passkey" ? "000000" : "PIN"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.space.sm
                    layoutDirection: Qt.RightToLeft

                    // Подтверждение — залитая пилюля на spatial-пружине;
                    // недоступная — 12 % on-surface с подписью 38 %.
                    Rectangle {
                        id: confirmButton

                        readonly property bool canConfirm: !root.needsInput || pinInput.text !== ""

                        width: confirmLabel.implicitWidth + Theme.space.xl * 2
                        height: Theme.touchTarget
                        radius: Theme.shape.full
                        color: confirmButton.canConfirm
                               ? Theme.primary
                               : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContainer)
                        scale: confirmHover.pressed && confirmButton.canConfirm ? 0.93
                             : (confirmHover.containsMouse && confirmButton.canConfirm ? 1.03 : 1)
                        Behavior on scale { SpringSpatialFast {} }

                        // Слой состояния: наведение поверх контейнера.
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.scheme.onPrimary
                            opacity: confirmHover.containsMouse && confirmButton.canConfirm ? Theme.stateHover : 0
                            Behavior on opacity { SpringEffects {} }
                        }

                        Text {
                            id: confirmLabel

                            anchors.centerIn: parent
                            text: root.informational ? "Готово" : "Подтвердить"
                            color: confirmButton.canConfirm
                                   ? Theme.scheme.onPrimary
                                   : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContent)
                            font: Theme.typeEmphasizedLabelLarge
                        }

                        MouseArea {
                            id: confirmHover

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: confirmButton.canConfirm
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.informational) {
                                    // BlueZ ответа не ждёт: просто закрываем окно.
                                    BluetoothBackend.agentRequest = null;
                                    return;
                                }
                                root.accept(pinInput.text);
                            }
                        }
                    }

                    // Отмена — текстовая кнопка-пилюля; при показе кода
                    // BlueZ ответа не ждёт, поэтому её нет.
                    Rectangle {
                        id: cancelButton

                        visible: !root.informational
                        width: cancelLabel.implicitWidth + Theme.space.xl * 2
                        height: Theme.touchTarget
                        radius: Theme.shape.full
                        color: "transparent"
                        scale: cancelHover.pressed ? 0.94 : (cancelHover.containsMouse ? 1.02 : 1)
                        Behavior on scale { SpringSpatialFast {} }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.stateLayer(Theme.primary, Theme.stateHover)
                            opacity: cancelHover.containsMouse ? 1 : 0
                            Behavior on opacity { SpringEffects {} }
                        }

                        Text {
                            id: cancelLabel

                            anchors.centerIn: parent
                            text: "Отмена"
                            color: Theme.primary
                            font: Theme.typeLabelLarge
                        }

                        MouseArea {
                            id: cancelHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.reject()
                        }
                    }
                }
            }
        }
    }

}
