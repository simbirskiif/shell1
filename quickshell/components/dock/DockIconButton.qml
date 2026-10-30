import QtQuick
import ".."
import "../../singletons"

// Круглая кнопка дока: раскрытие панели, настройки, закрытие.
// Наведение слегка поднимает и увеличивает кнопку — тот же отклик, что у
// иконок приложений, поэтому полоса не выглядит «статичной».
Item {
    id: root

    required property string icon

    property int size: 40
    property int glyphSize: 14
    // Акцентная заливка (кнопка раскрытия панели).
    property bool accented: false

    signal clicked()

    implicitWidth: root.size
    implicitHeight: root.size

    scale: hover.pressed ? 0.92 : (hover.containsMouse ? 1.08 : 1)
    Behavior on scale {
        MotionNumber {
            duration: Theme.motionShort3
            curve: Theme.curveDockExpressive
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.accented
               ? (hover.containsMouse ? Theme.quickTileActive : Theme.quickTile)
               : (hover.containsMouse ? Theme.quickTileHover : "transparent")
        Behavior on color {
            ColorAnimation { duration: Theme.motionShort3 }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.accented ? Theme.accent : Theme.quickText
        font.family: Theme.iconFontFamily
        font.pixelSize: root.glyphSize
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
