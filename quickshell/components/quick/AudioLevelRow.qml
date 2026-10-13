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
    implicitHeight: 58
    height: implicitHeight

    Rectangle {
        id: muteButton
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: width / 2
        color: muteHover.hovered ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            // Заглушённый канал показываем перечёркнутым глифом, иначе
            // непонятно, почему слайдер ничего не меняет.
            text: root.muted ? "\uf026" : root.icon
            color: root.muted ? Theme.quickTextDim : Theme.quickText
            font.family: Theme.iconFontFamily
            font.pixelSize: 15
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
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "Muted" : Math.round(root.value * 100) + "%"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    // Слайдер показывает сохранённую громкость и при mute: так видно, каким
    // будет уровень после снятия mute. Менять значение mute не мешает.
    PanelSlider {
        anchors.left: muteButton.right
        anchors.leftMargin: 10
        anchors.right: percent.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        value: root.value
        onMoved: v => root.moved(v)
    }
}
