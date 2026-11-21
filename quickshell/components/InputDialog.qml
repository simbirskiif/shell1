import QtQuick
import Quickshell
import Quickshell.Wayland
import "expressive"
import "../singletons"

// Окно правки одной строки настроек. Отдельная поверхность по той же
// причине, что и окно пароля: попап не может забрать клавиатурный фокус
// (Quickshell падает при keyboardFocus на PopupWindow), а PanelWindow может.
//
// Что редактируем — в UiState: requestInput() задаёт target, заголовок,
// подсказку и начальный текст, а результат уходит сигналом inputAccepted.
//
// Оформление — Material 3 Expressive: карточка радиуса 32, крупный орб-акцент
// с «печеньем», заголовок emphasized и высокое поле-пилюля с толстой
// обводкой primary. Подтверждение — залитая пилюля, сжимающаяся на пружине.
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
        Behavior on opacity { SpringEffects {} }

        MouseArea {
            anchors.fill: parent
            onClicked: UiState.cancelInput()
        }
    }

    // Карточка диалога: тональная поверхность surface-container-high и
    // крупный радиус 32. Границы и тени в M3 не нужны: глубину задаёт
    // сам тон поверхности.
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

            // Шапка: акцентный орб-«печенье» и заголовок с подсказкой.
            Item {
                width: parent.width
                implicitHeight: Math.max(accentOrb.height, titleColumn.implicitHeight)

                MorphShape {
                    id: accentOrb
                    width: Theme.touchTarget + Theme.space.md
                    height: width
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    shape: "cookie"
                    color: Theme.primaryContainer

                    Text {
                        anchors.centerIn: parent
                        text: "\uf040"
                        color: Theme.scheme.onPrimaryContainer
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
                        text: UiState.inputTitle
                        color: Theme.scheme.onSurface
                        font: Theme.typeEmphasizedHeadlineSmall
                    }

                    Text {
                        width: parent.width
                        visible: UiState.inputHint !== ""
                        wrapMode: Text.WordWrap
                        text: UiState.inputHint
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }
                }
            }

            // Поле ввода Expressive: высокий контейнер-пилюля (56) с толстой
            // обводкой primary — заметно даже без фокуса.
            Rectangle {
                width: parent.width
                height: Theme.listItemHeight
                radius: Theme.shape.full
                color: Theme.surfaceContainerHighest
                border.width: input.activeFocus ? 4 : 3
                border.color: Theme.primary
                Behavior on border.width { SpringSpatialFast {} }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.xl
                    anchors.rightMargin: Theme.space.xl
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.scheme.onSurface
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.scheme.onPrimary
                    font: Theme.typeTitleMedium
                    onAccepted: root.submit(input.text)
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

                // Залитая кнопка-пилюля 48 px: primary + on-primary,
                // пружина на нажатии.
                Rectangle {
                    id: saveButton
                    width: saveLabel.implicitWidth + Theme.space.xl * 2
                    height: Theme.touchTarget
                    radius: Theme.shape.full
                    color: Theme.primary
                    scale: saveHover.pressed ? 0.93 : (saveHover.containsMouse ? 1.04 : 1)
                    Behavior on scale { SpringSpatialFast {} }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.scheme.onPrimary
                        opacity: saveHover.containsMouse ? Theme.stateHover : 0
                        Behavior on opacity { SpringEffects {} }
                    }

                    Text {
                        id: saveLabel
                        anchors.centerIn: parent
                        text: "Сохранить"
                        color: Theme.scheme.onPrimary
                        font: Theme.typeEmphasizedLabelLarge
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
