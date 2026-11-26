import QtQuick
import ".."
import "../../singletons"

// Строка экрана в панели яркости: имя, модель и слайдер. Если управлять
// яркостью нельзя, вместо слайдера показывается причина.
Item {
    id: root

    required property string label
    required property string subtitle
    required property bool controllable
    required property real value
    property string hint: ""

    signal moved(real v)

    implicitWidth: parent ? parent.width : 0
    // Неуправляемый экран ниже: слайдера в нём нет, лишняя высота не нужна.
    implicitHeight: root.controllable ? Theme.listItemHeight + Theme.space.lg
                                      : Theme.listItemHeight
    height: implicitHeight

    Text {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: title.verticalCenter
        text: SystemIcons.brightnessGlyphFor(root.value, root.controllable)
        opacity: SystemIcons.brightnessOpacityFor(root.value, root.controllable)
        color: root.controllable ? Theme.scheme.onSurface
                                 : Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.md
    }

    Text {
        id: title
        anchors.left: icon.right
        anchors.leftMargin: Theme.space.md
        anchors.right: percent.left
        anchors.rightMargin: Theme.space.md
        anchors.top: parent.top
        anchors.topMargin: Theme.space.sm
        elide: Text.ElideRight
        text: root.label
        color: root.controllable ? Theme.scheme.onSurface
                                 : Theme.scheme.onSurfaceVariant
        font: Theme.typeBodyLarge
    }

    Text {
        id: percent
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.top: parent.top
        anchors.topMargin: Theme.space.sm
        width: Theme.space.xxxl
        horizontalAlignment: Text.AlignRight
        text: root.controllable ? Math.round(root.value * 100) + "%" : ""
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeBodyMedium
    }

    Text {
        anchors.left: title.left
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.top: title.bottom
        // У управляемого экрана здесь модель монитора, у остальных — почему
        // яркость недоступна: пользователю важно знать, что делать.
        text: root.controllable
              ? root.subtitle
              : (root.hint !== "" ? root.hint : "Not adjustable")
        elide: Text.ElideRight
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeBodySmall
    }

    PanelSlider {
        anchors.left: title.left
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.xs
        height: Theme.iconSize.md
        visible: root.controllable
        value: root.value
        onMoved: v => root.moved(v)
    }
}
