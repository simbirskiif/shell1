import QtQuick
import "../../singletons"

// Поле поиска в раскрытой панели. Своё, а не Controls.TextField: нужно
// попасть в палитру и motion-токены оболочки. M3 filled text field:
// контейнер surfaceContainerHighest, радиус shape.sm, текст bodyLarge,
// иконка 20, обводка outline (при фокусе — primary толщиной 2).
Rectangle {
    id: root

    property string placeholder: "Поиск приложений"
    property alias text: input.text

    signal edited(string value)
    signal navigate(int delta)
    signal moveHorizontal(int delta)
    signal submitted()

    implicitHeight: 36
    radius: Theme.shape.sm
    color: Theme.surfaceContainerHighest
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.primary : Theme.outline
    Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }
    Behavior on border.width { NumberAnimation { duration: Theme.motionShort3 } }

    function setText(value) {
        if (input.text !== value)
            input.text = value;
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    // Фон кликается по всей площади, включая иконку; сам TextInput лежит
    // сверху и забирает клики по тексту.
    MouseArea {
        anchors.fill: parent
        onClicked: root.focusInput()
    }

    Text {
        id: searchIcon
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf002"
        color: input.activeFocus ? Theme.primary : Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.md
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    Text {
        id: placeholderText
        anchors.left: input.left
        anchors.right: input.right
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text.length === 0
        text: root.placeholder
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeBodyLarge
        elide: Text.ElideRight
    }

    TextInput {
        id: input
        anchors.left: searchIcon.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: clearButton.left
        anchors.rightMargin: Theme.space.xs
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.scheme.onSurface
        selectionColor: Theme.primary
        selectedTextColor: Theme.scheme.onPrimary
        font: Theme.typeBodyLarge
        selectByMouse: true
        clip: true
        focus: DockState.keyboardActive && !DockState.settingsOpen

        onTextChanged: root.edited(input.text)
        onAccepted: root.submitted()

        // Поле не двигает каретку стрелками: они листают список.
        Keys.onUpPressed: {
            root.navigate(-1);
            event.accepted = true;
        }
        Keys.onDownPressed: {
            root.navigate(1);
            event.accepted = true;
        }

        // В плиточном виде ←/→ листают иконки, а не каретку поля.
        // В списке они остаются обычным перемещением по тексту.
        Keys.onLeftPressed: {
            if (!DockSettings.tileLayout)
                return;
            root.moveHorizontal(-1);
            event.accepted = true;
        }
        Keys.onRightPressed: {
            if (!DockSettings.tileLayout)
                return;
            root.moveHorizontal(1);
            event.accepted = true;
        }
    }

    Item {
        id: clearButton
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.xs
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.space.xxl
        height: Theme.space.xxl
        visible: input.text.length > 0

        // Круглая цель M3: в покое прозрачна, наведение — state layer.
        Rectangle {
            anchors.fill: parent
            radius: Theme.shape.full
            color: Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
            opacity: clearHover.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
        }

        MouseArea {
            id: clearHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
            onClicked: {
                input.text = "";
                root.focusInput();
            }
        }
    }
}
