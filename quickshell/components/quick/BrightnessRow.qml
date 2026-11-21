import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Строка экрана в панели яркости: имя, модель и слайдер. Если управлять
// яркостью нельзя, вместо слайдера показывается причина.
//
// Expressive: у управляемого экрана — орб-sunny на tertiary-контейнере,
// крупный процент и толстый слайдер с tertiary-акцентом (яркость — второй
// акцент панели).
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
    implicitHeight: root.controllable ? 96 : 68
    height: implicitHeight

    // Тональный контейнер-группа: строка держится формой и цветом,
    // а не разделителем.
    MorphShape {
        anchors.fill: parent
        anchors.topMargin: Theme.space.xs / 2
        anchors.bottomMargin: Theme.space.xs / 2
        shape: "squircle"
        color: Theme.surfaceContainerHigh
        modulation: 0.35
    }

    // Орб-солнце: у управляемого экрана — tertiary-контейнер, иначе тональная
    // поверхность. Форма «sunny» читается как источник яркости.
    MorphShape {
        id: iconOrb
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        shape: root.controllable ? "sunny" : "circle"
        color: root.controllable ? Theme.tertiaryContainer : Theme.surfaceContainerHighest
        modulation: 1

        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: "\uf185"
            color: root.controllable ? Theme.scheme.onTertiaryContainer
                                     : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: 22
        }
    }

    Text {
        id: title
        anchors.left: iconOrb.right
        anchors.leftMargin: Theme.space.md
        anchors.right: percent.left
        anchors.rightMargin: Theme.space.md
        anchors.top: parent.top
        anchors.topMargin: Theme.space.sm + 2
        elide: Text.ElideRight
        text: root.label
        color: root.controllable ? Theme.scheme.onSurface : Theme.scheme.onSurfaceVariant
        font: root.controllable ? Theme.typeEmphasizedLabelLarge : Theme.typeLabelLarge
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
        color: root.controllable ? Theme.tertiary : Theme.scheme.onSurfaceVariant
        font: Theme.typeEmphasizedTitleMedium
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
        height: 24
        visible: root.controllable
        accent: Theme.tertiary
        value: root.value
        onMoved: v => root.moved(v)
    }
}
