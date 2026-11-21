import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Строка уровня звука: кнопка mute, слайдер и процент.
// Компонент «глупый»: значение и mute приходят снаружи, наружу уходят
// сигналы moved/muteToggled — поэтому он годится и для вывода, и для входа.
//
// Expressive: это главный элемент панели — крупный орб 52 и толстый
// волнистый слайдер с primary-акцентом.
Item {
    id: root

    required property string icon
    required property bool muted
    required property real value

    signal moved(real v)
    signal muteToggled()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 84
    height: implicitHeight

    // Тональная группа-контейнер: герой панели держится формой и цветом.
    MorphShape {
        anchors.fill: parent
        anchors.topMargin: Theme.space.xs / 2
        anchors.bottomMargin: Theme.space.xs / 2
        shape: "squircle"
        color: Theme.surfaceContainerHigh
        modulation: 0.35
    }

    // Кнопка-mute: крупный орб, при нажатии сжимается, у заглушённого —
    // «печенье» на error-контейнере.
    MorphShape {
        id: muteButton
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 52
        shape: root.muted ? "cookie" : (muteHover.containsMouse ? "squircle" : "circle")
        color: root.muted ? Theme.errorContainer
             : muteHover.containsMouse ? Theme.tertiaryContainer
             : Theme.primaryContainer
        modulation: 1
        scale: muteHover.pressed ? 0.92 : 1

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { SpringSpatialFast {} }

        Text {
            anchors.centerIn: parent
            // Заглушённый канал показываем перечёркнутым глифом, иначе
            // непонятно, почему слайдер ничего не меняет.
            text: root.muted ? "\uf026" : root.icon
            color: root.muted ? Theme.scheme.onErrorContainer
                 : muteHover.containsMouse ? Theme.scheme.onTertiaryContainer
                 : Theme.scheme.onPrimaryContainer
            font.family: Theme.iconFontFamily
            font.pixelSize: 24
            Behavior on color { ColorAnimation { duration: 140 } }
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
        width: Theme.space.xxxl + Theme.space.sm
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "Muted" : Math.round(root.value * 100) + "%"
        color: root.muted ? Theme.scheme.onSurfaceVariant : Theme.primary
        font: Theme.typeEmphasizedTitleMedium
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // Слайдер показывает сохранённую громкость и при mute: так видно, каким
    // будет уровень после снятия mute. Менять значение mute не мешает.
    PanelSlider {
        anchors.left: muteButton.right
        anchors.leftMargin: Theme.space.md
        anchors.right: percent.left
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        accent: Theme.primary
        value: root.value
        onMoved: v => root.moved(v)
    }
}
