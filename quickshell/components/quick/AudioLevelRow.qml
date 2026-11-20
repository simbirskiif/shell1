import QtQuick
import ".."
import "../../singletons"

// Строка уровня звука: кнопка mute, слайдер и процент.
// Компонент «глупый»: значение и mute приходят снаружи, наружу уходят
// сигналы moved/muteToggled — поэтому он годится и для вывода, и для входа.
Item {
    id: root

    required property string icon
    required property bool muted
    required property real value

    signal moved(real v)
    signal muteToggled()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.listItemHeight
    height: implicitHeight

    // Кнопка-иконка m3: 40×40, круглая, hover — state layer on-surface.
    Rectangle {
        id: muteButton
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconButtonSize
        height: Theme.iconButtonSize
        radius: Theme.shape.full
        color: muteHover.containsMouse
               ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            // Заглушённый канал показываем перечёркнутым глифом, иначе
            // непонятно, почему слайдер ничего не меняет.
            text: root.muted ? "\uf026" : root.icon
            color: root.muted ? Theme.scheme.onSurfaceVariant : Theme.scheme.onSurface
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        MouseArea {
            id: muteHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.muteToggled()
        }
    }

    Text {
        id: percent
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.space.xxxl
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "Muted" : Math.round(root.value * 100) + "%"
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeBodyMedium
    }

    // Слайдер показывает сохранённую громкость и при mute: так видно, каким
    // будет уровень после снятия mute. Менять значение mute не мешает.
    PanelSlider {
        anchors.left: muteButton.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: percent.left
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.iconSize.md + Theme.space.xs
        value: root.value
        onMoved: v => root.moved(v)
    }
}
