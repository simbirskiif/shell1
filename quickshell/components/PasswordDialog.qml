import QtQuick
import Quickshell
import Quickshell.Wayland
import "quick"
import "../singletons"

// Модальное окно ввода пароля. Отдельная поверхность на весь экран:
// попап не может забрать клавиатурный фокус (Quickshell падает при
// keyboardFocus на PopupWindow), а PanelWindow — может.
//
// Окно открывается не «по клику», а по изменению NetworkService.pendingNetwork:
// пароль может понадобиться и позже, асинхронно — например, у сохранённой
// сети сменился пароль на роутере.
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
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveStandard
            }
        }

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

    // Карточка диалога: surface-container-high, радиус dialogs (shape.xl).
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380
        height: cardColumn.implicitHeight + Theme.space.xl * 2
        radius: Theme.shape.xl
        color: Theme.surfaceContainerHigh
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : Theme.motionFadeThroughScale
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveStandard
            }
        }
        Behavior on scale {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasizedDecelerate
            }
        }

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
            spacing: Theme.space.md

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.changing ? I18n.tr("dialogs.password.new")
                                    : I18n.tr("dialogs.password.enter")
                color: Theme.scheme.onSurface
                font: Theme.typeHeadlineSmall
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: NetworkService.pendingNetwork
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodyMedium
            }

            // Ошибка — тональная плашка error-container с текстом
            // on-error-container, как в M3, а не просто красная строка.
            Rectangle {
                width: parent.width
                height: errorLabel.implicitHeight + Theme.space.md * 2
                visible: root.failed
                radius: Theme.shape.xs
                color: Theme.errorContainer

                Text {
                    id: errorLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space.md
                    anchors.rightMargin: Theme.space.md
                    wrapMode: Text.WordWrap
                    text: root.changing
                          ? I18n.tr("dialogs.password.rejected.change")
                          : I18n.tr("dialogs.password.rejected")
                    color: Theme.scheme.onErrorContainer
                    font: Theme.typeBodyMedium
                }
            }

            // Поле ввода M3: контейнер surface-container-highest, радиус
            // shape.xs, обводка outline (фокус — primary толщиной 2,
            // ошибка — error).
            Rectangle {
                width: parent.width
                height: Theme.listItemHeight
                radius: Theme.shape.xs
                color: Theme.surfaceContainerHighest
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: root.failed ? Theme.error
                                          : (passwordInput.activeFocus ? Theme.primary : Theme.outline)
                Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.iconButtonSize + Theme.space.sm
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: root.revealed ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    color: Theme.scheme.onSurface
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.scheme.onPrimary
                    font: Theme.typeBodyLarge
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
                        text: I18n.tr("dialogs.password.placeholder")
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodySmall
                    }
                }

                // Показать/скрыть пароль — иконка-кнопка M3 40×40.
                Item {
                    id: revealButton
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconButtonSize
                    height: Theme.iconButtonSize

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shape.full
                        color: revealHover.containsMouse
                               ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
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

                // Текстовая кнопка M3: подпись primary, фон только под
                // состоянием наведения (state layer).
                Rectangle {
                    id: cancelButton
                    width: cancelLabel.implicitWidth + Theme.space.xl * 2
                    height: Theme.buttonHeight
                    radius: Theme.shape.full
                    color: cancelHover.containsMouse ? Theme.stateLayer(Theme.primary, Theme.stateHover)
                                               : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: I18n.tr("common.cancel")
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

                // Залитая кнопка M3: пилюля 40 px, primary + on-primary;
                // недоступная — 12 % on-surface с подписью 38 %.
                Rectangle {
                    id: connectButton
                    width: connectLabel.implicitWidth + Theme.space.xl * 2
                    height: Theme.buttonHeight
                    radius: Theme.shape.full
                    color: root.connecting
                           ? Theme.primaryContainer
                           : (root.readyToSubmit
                              ? Theme.primary
                              : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContainer))

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.scheme.onPrimary
                        opacity: connectHover.containsMouse && !root.connecting ? Theme.stateHover : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                    }

                    Text {
                        id: connectLabel
                        anchors.centerIn: parent
                        visible: !root.connecting
                        text: I18n.tr("dialogs.password.connect")
                        color: root.readyToSubmit
                               ? Theme.scheme.onPrimary
                               : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContent)
                        font: Theme.typeLabelLarge
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
