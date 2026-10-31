import QtQuick
import "../../singletons"

// Поле поиска в раскрытой панели. Своё, а не Controls.TextField: нужно
// попасть в палитру и motion-токены оболочки.
Rectangle {
    id: root

    property string placeholder: "Поиск приложений"
    property alias text: input.text

    signal edited(string value)
    signal navigate(int delta)
    signal submitted()

    implicitHeight: 36
    radius: 12
    color: Theme.quickTile
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.accent : Theme.quickBorder
    Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

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
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf002"
        color: input.activeFocus ? Theme.accent : Theme.quickTextDim
        font.family: Theme.iconFontFamily
        font.pixelSize: Math.max(12, Math.min(18, Math.round(root.height * 0.39)))
    }

    Text {
        id: placeholderText
        anchors.left: input.left
        anchors.right: input.right
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text.length === 0
        text: root.placeholder
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(11, Math.min(16, Math.round(root.height * 0.34)))
        elide: Text.ElideRight
    }

    TextInput {
        id: input
        anchors.left: searchIcon.right
        anchors.leftMargin: 8
        anchors.right: clearButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.quickText
        selectionColor: Theme.accent
        selectedTextColor: Theme.quickIconOn
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(11, Math.min(16, Math.round(root.height * 0.34)))
        selectByMouse: true
        clip: true
        focus: DockState.expanded && !DockState.settingsOpen

        onTextChanged: root.edited(input.text)
        onAccepted: root.submitted()

        Keys.onUpPressed: {
            root.navigate(-1);
            event.accepted = true;
        }
        Keys.onDownPressed: {
            root.navigate(1);
            event.accepted = true;
        }
    }

    Item {
        id: clearButton
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        visible: input.text.length > 0

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: clearHover.containsMouse ? Theme.quickTileHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 11
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
