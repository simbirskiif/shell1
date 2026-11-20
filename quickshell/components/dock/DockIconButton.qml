import QtQuick
import ".."
import "../../singletons"

// Круглая кнопка дока: раскрытие панели, настройки, закрытие. M3 icon button:
// круг shape.full, контейнер — прозрачный или tonal (secondaryContainer),
// наведение — state layer. Наведение слегка поднимает и увеличивает кнопку —
// тот же отклик, что у иконок приложений, поэтому полоса не «статична».
Item {
    id: root

    required property string icon

    property int size: Theme.iconButtonSize
    property int glyphSize: Theme.iconSize.md
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

    // Тональный контейнер M3: акцентная кнопка — secondaryContainer,
    // обычная — прозрачная (поверхность карточки остаётся видна).
    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.full
        color: root.accented ? Theme.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    // Слой состояния M3: наведение/нажатие поверх контейнера.
    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.full
        color: Theme.stateLayer(root.accented ? Theme.scheme.onSecondaryContainer
                                              : Theme.scheme.onSurface,
                                hover.pressed ? Theme.statePressed : Theme.stateHover)
        opacity: hover.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.accented ? Theme.scheme.onSecondaryContainer
                             : Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: root.glyphSize
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
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
