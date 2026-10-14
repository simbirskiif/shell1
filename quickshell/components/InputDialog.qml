import QtQuick
import Quickshell
import Quickshell.Wayland
import "../singletons"

// Окно правки одной строки настроек. Отдельная поверхность по той же
// причине, что и окно пароля: попап не может забрать клавиатурный фокус
// (Quickshell падает при keyboardFocus на PopupWindow), а PanelWindow может.
//
// Что редактируем — в UiState: requestInput() задаёт target, заголовок,
// подсказку и начальный текст, а результат уходит сигналом inputAccepted.
PanelWindow {
    id: root

    required property ShellScreen dialogScreen

    readonly property string screenName: root.dialogScreen ? root.dialogScreen.name : ""

    screen: dialogScreen
    visible: UiState.inputTarget !== ""
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
    WlrLayershell.namespace: "quickshell-input"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (!visible)
            return;
        input.text = UiState.inputText;
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
    }

    function submit(value) {
        UiState.submitInput(value);
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
            onClicked: UiState.cancelInput()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380
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
                text: UiState.inputTitle
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                visible: UiState.inputHint !== ""
                wrapMode: Text.WordWrap
                text: UiState.inputHint
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: 12
                color: Theme.quickTile
                border.width: input.activeFocus ? 2 : 1
                border.color: input.activeFocus ? Theme.accent : Theme.quickBorder
                Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.quickText
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.quickIconOn
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    onAccepted: root.submit(input.text)
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
                        text: "Отмена"
                        color: Theme.quickText
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: cancelHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: UiState.cancelInput()
                    }
                }

                Rectangle {
                    id: saveButton
                    width: saveLabel.implicitWidth + 36
                    height: 36
                    radius: height / 2
                    color: Theme.accent

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.quickIconOn
                        opacity: saveHover.hovered ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                    }

                    Text {
                        id: saveLabel
                        anchors.centerIn: parent
                        text: "Сохранить"
                        color: Theme.quickIconOn
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: saveHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit(input.text)
                    }
                }
            }
        }
    }
}
