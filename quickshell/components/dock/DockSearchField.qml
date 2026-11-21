import QtQuick
import "../expressive"
import "../../singletons"

// Поле поиска в раскрытой панели. Своё, а не Controls.TextField: нужно
// попасть в палитру и motion-токены оболочки.
//
// Expressive: контейнер — не прямоугольник, а морфящаяся форма: в покое
// пилюля, в фокусе — «печенье» с толстой обводкой primary. Текст крупный
// (titleMedium), поэтому поле читается как главный элемент панели, а не
// как служебная строка. Кнопка очистки при наведении становится burst'ом.
Item {
    id: root

    property string placeholder: "Поиск приложений"
    property alias text: input.text

    signal edited(string value)
    signal navigate(int delta)
    signal moveHorizontal(int delta)
    signal submitted()

    implicitHeight: 40

    readonly property bool focused: input.activeFocus
    readonly property bool hovered: hoverArea.containsMouse

    function setText(value) {
        if (input.text !== value)
            input.text = value;
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    // Контейнер — пилюля shape.full: на такой широкой строке полярная
    // форма MorphShape «заостряется» в линзу, поэтому крупную геометрию
    // держит обычный stadium, а выразительность даёт cookie-орб иконки.
    // Толстая обводка primary появляется только в фокусе.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.hovered && !root.focused ? Theme.surfaceContainerHigh
                                             : Theme.surfaceContainerHighest
        border.width: root.focused ? 3 : 0
        border.color: Theme.primary
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.width { SpringSpatialFast {} }
    }

    // Фон кликается по всей площади, включая иконку; сам TextInput лежит
    // сверху и забирает клики по тексту.
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.focusInput()
    }

    // Иконка поиска живёт в орбе: в покое — круг тональной поверхности,
    // в фокусе — cookie tertiary-контейнера. Состояние поля читается
    // формой, как у остальных expressive-элементов дока.
    MorphShape {
        id: searchOrb
        anchors.left: parent.left
        anchors.leftMargin: root.focused ? Theme.space.md : Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        shape: root.focused ? "sunny" : "circle"
        modulation: 0.75
        color: root.focused ? Theme.tertiaryContainer : Theme.surfaceContainerHigh
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: searchIcon
        anchors.centerIn: searchOrb
        text: "\uf002"
        color: root.focused ? Theme.scheme.onTertiaryContainer
                            : Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.sm + 2
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    TextInput {
        id: input
        anchors.left: searchOrb.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: clearButton.left
        anchors.rightMargin: Theme.space.xs
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.scheme.onSurface
        selectionColor: Theme.primary
        selectedTextColor: Theme.scheme.onPrimary
        font: Theme.typeEmphasizedTitleMedium
        selectByMouse: true
        clip: true
        focus: DockState.keyboardActive && !DockState.settingsOpen

        onTextChanged: root.edited(input.text)
        onAccepted: root.submitted()

        // Поле не двигает каретку стрелками: они листают список.
        Keys.onUpPressed: function (event) {
            root.navigate(-1);
            event.accepted = true;
        }
        Keys.onDownPressed: function (event) {
            root.navigate(1);
            event.accepted = true;
        }

        // В плиточном виде ←/→ листают иконки, а не каретку поля.
        // В списке они остаются обычным перемещением по тексту.
        Keys.onLeftPressed: function (event) {
            if (!DockSettings.tileLayout)
                return;
            root.moveHorizontal(-1);
            event.accepted = true;
        }
        Keys.onRightPressed: function (event) {
            if (!DockSettings.tileLayout)
                return;
            root.moveHorizontal(1);
            event.accepted = true;
        }
    }

    Text {
        anchors.left: input.left
        anchors.right: input.right
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text.length === 0
        text: root.placeholder
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeTitleMedium
        elide: Text.ElideRight
    }

    Item {
        id: clearButton
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.space.xxl
        height: Theme.space.xxl
        visible: input.text.length > 0

        // Кнопка очистки: круг в покое, «взрыв» при наведении —
        // мелкая, но выразительная деформация формы.
        MorphShape {
            anchors.fill: parent
            shape: clearHover.containsMouse ? "burst" : "circle"
            modulation: clearHover.containsMouse ? 0.5 : 0.9
            color: clearHover.containsMouse ? Theme.tertiaryContainer : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: clearHover.containsMouse ? Theme.scheme.onTertiaryContainer
                                            : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
            Behavior on color { ColorAnimation { duration: 140 } }
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
