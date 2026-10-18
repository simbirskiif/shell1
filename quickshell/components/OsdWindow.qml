import QtQuick
import "../singletons"

// Индикатор громкости и яркости — тонкая длинная карточка: иконка слева,
// название источника по центру, процент справа и полоска уровня во всю
// ширину снизу. Оболочка (окно, выезд, позиция) — в OsdPopup, здесь только
// содержимое.
OsdPopup {
    id: root

    shown: Osd.shown
    cardWidth: 520
    cardHeight: 44

    // Значение, которое догоняет Osd.value: и полоска, и процент едут
    // анимацией, а не прыгают.
    property real displayValue: 0
    Behavior on displayValue {
        MotionNumber {
            duration: Theme.motionMedium1
            curve: Theme.curveStandard
        }
    }

    Connections {
        target: Osd

        function onValueChanged() {
            root.displayValue = Osd.muted ? 0 : Osd.value;
        }

        function onMutedChanged() {
            root.displayValue = Osd.muted ? 0 : Osd.value;
        }
    }

    Component.onCompleted: root.displayValue = Osd.muted ? 0 : Osd.value

    Text {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        text: Osd.muted ? "\uf026"
            : Osd.kind === "input" ? "\uf130"
            : Osd.kind === "brightness" ? "\uf185"
            : "\uf028"
        color: Osd.muted ? Theme.quickTextDim : Theme.quickText
        font.family: Theme.iconFontFamily
        font.pixelSize: 15
    }

    Text {
        id: percent
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        width: 52
        horizontalAlignment: Text.AlignRight
        text: Osd.muted ? "Выкл." : Math.round(root.displayValue * 100) + "%"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    // Имя источника по центру: «Speaker», «Digital Microphone», «eDP-1».
    Text {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: percent.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        horizontalAlignment: Text.AlignHCenter
        text: Osd.title
        elide: Text.ElideRight
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    // Полоска уровня во всю ширину, без кружка и без управления.
    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 4
        color: Theme.quickCircleOff

        Rectangle {
            width: track.width * root.displayValue
            height: parent.height
            color: Theme.accent
        }
    }
}
