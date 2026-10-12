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

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
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

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 360
        height: cardColumn.implicitHeight + Theme.quickPadding * 2
        radius: Theme.quickRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder
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
            anchors.margins: Theme.quickPadding
            spacing: 6

            Text {
                text: root.changing ? "New password" : "Enter password"
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Text {
                text: NetworkService.pendingNetwork
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                width: parent.width
                visible: root.failed
                wrapMode: Text.WordWrap
                text: root.changing ? "Password was not accepted, try another one"
                                    : "Wrong password, try again"
                color: Theme.lowColor
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: 12
                color: Theme.quickTile
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: root.failed ? Theme.lowColor
                                          : (passwordInput.activeFocus ? Theme.accent : Theme.quickBorder)
                Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 44
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: root.revealed ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    color: Theme.quickText
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.quickIconOn
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
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
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }

                // Показать/скрыть пароль.
                Item {
                    id: revealButton
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: revealHover.hovered ? Theme.quickTileHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.revealed ? "\uf070" : "\uf06e"
                        color: root.revealed ? Theme.accent : Theme.quickTextDim
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 13
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

            Item { width: 1; height: 4 }

            Row {
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    id: cancelButton
                    width: cancelLabel.implicitWidth + 32
                    height: 36
                    radius: height / 2
                    color: cancelHover.hovered ? Theme.quickTileHover : Theme.quickTile
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.quickText
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: cancelHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NetworkService.cancelPending()
                    }
                }

                Rectangle {
                    id: connectButton
                    width: connectLabel.implicitWidth + 36
                    height: 36
                    radius: height / 2
                    color: Theme.accent
                    opacity: root.readyToSubmit ? 1 : 0.6

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.quickIconOn
                        opacity: connectHover.hovered ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                    }

                    Text {
                        id: connectLabel
                        anchors.centerIn: parent
                        visible: !root.connecting
                        text: "Connect"
                        color: Theme.quickIconOn
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    LoadingIndicator {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
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
