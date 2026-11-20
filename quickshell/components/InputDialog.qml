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
            onClicked: UiState.cancelInput()
        }
    }

    // Карточка диалога: тональная поверхность surface-container-high и
    // радиус dialogs (shape.xl). Границы и тени в M3 не нужны: глубину
    // задаёт сам тон поверхности.
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
                text: UiState.inputTitle
                color: Theme.scheme.onSurface
                font: Theme.typeHeadlineSmall
            }

            Text {
                width: parent.width
                visible: UiState.inputHint !== ""
                wrapMode: Text.WordWrap
                text: UiState.inputHint
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodyMedium
            }

            // Поле ввода M3: контейнер surface-container-highest, радиус
            // shape.xs, обводка outline; в фокусе — primary толщиной 2.
            Rectangle {
                width: parent.width
                height: Theme.listItemHeight
                radius: Theme.shape.xs
                color: Theme.surfaceContainerHighest
                border.width: input.activeFocus ? 2 : 1
                border.color: input.activeFocus ? Theme.primary : Theme.outline
                Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.space.lg
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.scheme.onSurface
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.scheme.onPrimary
                    font: Theme.typeBodyLarge
                    onAccepted: root.submit(input.text)
                }
            }

            Item { width: 1; height: Theme.space.xs }

            Row {
                anchors.right: parent.right
                spacing: Theme.space.sm

                // Текстовая кнопка M3: прозрачный контейнер, подпись primary,
                // состояние наведения — state layer.
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
                        text: "Отмена"
                        color: Theme.primary
                        font: Theme.typeLabelLarge
                    }

                    MouseArea {
                        id: cancelHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: UiState.cancelInput()
                    }
                }

                // Залитая кнопка M3: пилюля 40 px, primary + on-primary.
                Rectangle {
                    id: saveButton
                    width: saveLabel.implicitWidth + Theme.space.xl * 2
                    height: Theme.buttonHeight
                    radius: Theme.shape.full
                    color: Theme.primary

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.scheme.onPrimary
                        opacity: saveHover.containsMouse ? Theme.stateHover : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                    }

                    Text {
                        id: saveLabel
                        anchors.centerIn: parent
                        text: "Сохранить"
                        color: Theme.scheme.onPrimary
                        font: Theme.typeLabelLarge
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
