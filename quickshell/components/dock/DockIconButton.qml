import QtQuick
import "../expressive"
import "../../singletons"

// Кнопка-иконка дока: настройки, закрытие, переключение вида.
//
// Expressive: контейнер — морфящаяся форма, а не просто круг. Акцентная
// кнопка — «печенье» tertiary-контейнера, обычная в покое прозрачна, при
// наведении превращается в squircle тональной поверхности. Нажатие
// сжимает кнопку на spatial-пружине; тонкая обводка не используется —
// состояние читается формой и цветом.
Item {
    id: root

    required property string icon

    property int size: Theme.iconButtonSize
    property int glyphSize: Theme.iconSize.md
    // Акцентная заливка (кнопка настроек панели).
    property bool accented: false

    signal clicked()

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property bool hovered: hover.containsMouse
    readonly property bool pressed: hover.pressed

    scale: root.pressed ? 0.9 : (root.hovered ? 1.06 : 1)
    Behavior on scale { SpringSpatialFast {} }

    // Контейнер-форма: акцент — cookie на tertiary-container, наведение —
    // squircle тональной поверхности, в покое формы нет.
    MorphShape {
        anchors.fill: parent
        shape: root.pressed ? "squircle"
             : root.accented ? "cookie"
             : (root.hovered ? "squircle" : "circle")
        modulation: 0.8
        color: root.accented ? Theme.tertiaryContainer
             : root.hovered ? Theme.surfaceContainerHighest
             : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.accented ? Theme.scheme.onTertiaryContainer
                             : Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: root.glyphSize
        scale: root.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { SpringSpatialFast {} }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Панель не должна спрятаться, пока курсор на кнопке, даже если
        // обработчик наведения окна на миг сработал раньше дочернего.
        onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
        onClicked: root.clicked()
    }
}
