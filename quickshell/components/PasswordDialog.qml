import QtQuick
import Quickshell
import Quickshell.Wayland
import "quick"
import "expressive"
import "../singletons"

// Модальное окно ввода пароля. Отдельная поверхность на весь экран:
// попап не может забрать клавиатурный фокус (Quickshell падает при
// keyboardFocus на PopupWindow), а PanelWindow — может.
//
// Окно открывается не «по клику», а по изменению NetworkService.pendingNetwork:
// пароль может понадобиться и позже, асинхронно — например, у сохранённой
// сети сменился пароль на роутере.
//
// Оформление — Material 3 Expressive: крупная карточка с радиусом 32,
// контрастный орб-акцент, который морфится из cookie в burst при ошибке,
// высокое поле-пилюля с толстой обводкой primary и кнопки-пилюли на пружине.
PanelWindow {
    id: root

    required property ShellScreen dialogScreen

    readonly property string screenName: root.dialogScreen ? root.dialogScreen.name : ""
    readonly property bool connecting: NetworkService.connectingName !== ""
                                        && NetworkService.connectingName === NetworkService.pendingNetwork
    readonly property bool failed: NetworkService.connectError === "auth"
    readonly property bool readyToSubmit: !connecting && passwordInput.text !== ""
    // Окно открыто из меню «Сменить пароль», а не для подключения к новой сети.
    readonly property bool changing: NetworkService.passwordChange
    // По умолчанию пароль скрыт; глазок справа включает просмотр.
    property bool revealed: false
    // Пароль уже пробовали отправить — если он не подошёл, оставляем его в
    // поле, чтобы можно было поправить опечатку, а не набирать заново.
    property string lastAttempt: ""

    screen: dialogScreen
    visible: NetworkService.pendingNetwork !== ""
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
    WlrLayershell.namespace: "quickshell-password"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Пароль не должен переживать закрытие окна.
    onVisibleChanged: {
        if (visible) {
            passwordInput.text = lastAttempt;
            root.revealed = false;
            passwordInput.forceActiveFocus();
            passwordInput.cursorPosition = passwordInput.text.length;
        } else {
            lastAttempt = "";
            NetworkService.pendingPassword = "";
        }
    }

    // При неудаче возвращаем в поле то, что вводили: чаще всего это опечатка.
    onFailedChanged: {
        if (failed && lastAttempt !== "" && passwordInput.text === "") {
            passwordInput.text = lastAttempt;
            passwordInput.forceActiveFocus();
            passwordInput.cursorPosition = passwordInput.text.length;
        }
    }

    // Затемнение фона — ролью scrim, а не произвольным чёрным.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrimOverlay
        opacity: root.visible ? 1 : 0
        Behavior on opacity { SpringEffects {} }

        MouseArea {
            anchors.fill: parent
            onClicked: NetworkService.cancelPending()
        }
    }

    function submit(value) {
        if (value === "")
            return;
        lastAttempt = value;
        NetworkService.submitPassword(value);
        // Пароль уже ушёл в NM: в поле он нужен только для просмотра, а в
        // сервисе не хранится.
        NetworkService.pendingPassword = "";
    }

    // Карточка диалога: surface-container-high, крупный радиус 32.
    // Глубину задаёт тон поверхности, а не тень.
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 400
        height: cardColumn.implicitHeight + Theme.space.xl * 2
        radius: Theme.shape.xlIncreased
        color: Theme.surfaceContainerHigh
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : Theme.motionFadeThroughScale
        Behavior on opacity { SpringEffects {} }
        Behavior on scale { SpringSpatial {} }

        // Клики по карточке не должны закрывать окно.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.space.xl
            spacing: Theme.space.lg

            // Шапка: крупный акцентный орб. Ошибка читается не только
            // цветом, но и формой — cookie спокойный, burst «взрывается».
            Item {
                width: parent.width
                implicitHeight: Math.max(accentOrb.height, titleColumn.implicitHeight)

                MorphShape {
                    id: accentOrb
                    width: Theme.touchTarget + Theme.space.md
                    height: width
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    shape: root.failed ? "burst" : "cookie"
                    color: root.failed ? Theme.errorContainer : Theme.primaryContainer

                    Text {
                        anchors.centerIn: parent
                        text: root.failed ? "\uf071" : "\uf023"
                        color: root.failed ? Theme.scheme.onErrorContainer
                                           : Theme.scheme.onPrimaryContainer
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.lg + Theme.space.xs
                    }
                }

                Column {
                    id: titleColumn
                    anchors.left: accentOrb.right
                    anchors.leftMargin: Theme.space.lg
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xs

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: root.changing ? "New password" : "Enter password"
                        color: Theme.scheme.onSurface
                        font: Theme.typeEmphasizedHeadlineSmall
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: NetworkService.pendingNetwork
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }
                }
            }

            // Ошибка — тональная плашка error-container с текстом
            // on-error-container, как в M3, а не просто красная строка.
            Rectangle {
                width: parent.width
                height: errorLabel.implicitHeight + Theme.space.md * 2
                visible: root.failed
                radius: Theme.shape.lg
                color: Theme.errorContainer

                Text {
                    id: errorIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf071"
                    color: Theme.scheme.onErrorContainer
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    id: errorLabel
                    anchors.left: errorIcon.right
                    anchors.leftMargin: Theme.space.sm
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.WordWrap
                    text: root.changing ? "Password was not accepted, try another one"
                                        : "Wrong password, try again"
                    color: Theme.scheme.onErrorContainer
                    font: Theme.typeBodyMedium
                }
            }

            // Поле ввода Expressive: высокий контейнер-пилюля (56), толстая
            // обводка primary (в фокусе — ещё толще, при ошибке — error).
            Rectangle {
                width: parent.width
                height: Theme.listItemHeight
                radius: Theme.shape.full
                color: Theme.surfaceContainerHighest
                border.width: root.failed || passwordInput.activeFocus ? 4 : 3
                border.color: root.failed ? Theme.error : Theme.primary
                Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.xl
                    anchors.rightMargin: Theme.touchTarget + Theme.space.sm
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: root.revealed ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    color: Theme.scheme.onSurface
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.scheme.onPrimary
                    font: Theme.typeTitleMedium
                    enabled: !root.connecting
                    // Текст поля — источник истины для окна; сервис получает
                    // пароль только в submitPassword.
                    onTextChanged: {
                        if (NetworkService.connectError !== "")
                            NetworkService.connectError = "";
                        NetworkService.pendingPassword = text;
                    }
                    onAccepted: root.submit(passwordInput.text)

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text === "" && !root.revealed
                        text: "Network password"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }
                }

                // Показать/скрыть пароль — круглая кнопка-орб: форма и
                // цвет меняются, само нажатие сжимается на пружине.
                Item {
                    id: revealButton
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.xs
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.touchTarget
                    height: Theme.touchTarget
                    scale: revealHover.pressed ? 0.9 : (revealHover.containsMouse ? 1.06 : 1)
                    Behavior on scale { SpringSpatialFast {} }

                    MorphShape {
                        anchors.fill: parent
                        shape: revealHover.containsMouse ? "squircle" : "circle"
                        color: revealHover.containsMouse
                               ? Theme.stateLayer(Theme.primary, Theme.stateHover) : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.revealed ? "\uf070" : "\uf06e"
                        color: root.revealed ? Theme.primary : Theme.scheme.onSurfaceVariant
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.lg
                    }

                    MouseArea {
                        id: revealHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.revealed = !root.revealed;
                            passwordInput.forceActiveFocus();
                            passwordInput.cursorPosition = passwordInput.text.length;
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.space.xs }

            Row {
                anchors.right: parent.right
                spacing: Theme.space.sm

                // Текстовая кнопка отказа: прозрачный пилюльный контейнер,
                // подпись primary, сжатие на пружине.
                Rectangle {
                    id: cancelButton
                    width: cancelLabel.implicitWidth + Theme.space.xl * 2
                    height: Theme.touchTarget
                    radius: Theme.shape.full
                    color: cancelHover.containsMouse ? Theme.stateLayer(Theme.primary, Theme.stateHover)
                                               : "transparent"
                    scale: cancelHover.pressed ? 0.94 : 1
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                    Behavior on scale { SpringSpatialFast {} }

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.primary
                        font: Theme.typeLabelLarge
                    }

                    MouseArea {
                        id: cancelHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NetworkService.cancelPending()
                    }
                }

                // Залитая кнопка-пилюля 48 px: primary + on-primary,
                // недоступная — 12 % on-surface с подписью 38 %.
                Rectangle {
                    id: connectButton
                    width: connectLabel.implicitWidth + Theme.space.xl * 2
                    height: Theme.touchTarget
                    radius: Theme.shape.full
                    color: root.connecting
                           ? Theme.primaryContainer
                           : (root.readyToSubmit
                              ? Theme.primary
                              : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContainer))
                    scale: connectHover.pressed && root.readyToSubmit ? 0.93
                         : (connectHover.containsMouse && root.readyToSubmit ? 1.04 : 1)
                    Behavior on scale { SpringSpatialFast {} }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.scheme.onPrimary
                        opacity: connectHover.containsMouse && !root.connecting ? Theme.stateHover : 0
                        Behavior on opacity { SpringEffects {} }
                    }

                    Text {
                        id: connectLabel
                        anchors.centerIn: parent
                        visible: !root.connecting
                        text: "Connect"
                        color: root.readyToSubmit
                               ? Theme.scheme.onPrimary
                               : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContent)
                        font: Theme.typeEmphasizedLabelLarge
                    }

                    LoadingIndicator {
                        anchors.centerIn: parent
                        width: Theme.iconSize.md
                        height: Theme.iconSize.md
                        visible: root.connecting
                    }

                    MouseArea {
                        id: connectHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.readyToSubmit
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit(passwordInput.text)
                    }
                }
            }
        }

        Component.onCompleted: passwordInput.forceActiveFocus()
        onVisibleChanged: if (visible) passwordInput.forceActiveFocus()
    }
}
