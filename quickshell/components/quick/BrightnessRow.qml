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
    implicitHeight: root.controllable ? 66 : 50
    height: implicitHeight

    Text {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 12
        text: "\uf185"
        color: root.controllable ? Theme.quickText : Theme.quickTextDim
        font.family: Theme.iconFontFamily
        font.pixelSize: 15
    }

    Text {
        id: title
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: percent.left
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 10
        text: root.label
        elide: Text.ElideRight
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    Text {
        id: percent
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 10
        width: 42
        horizontalAlignment: Text.AlignRight
        text: root.controllable ? Math.round(root.value * 100) + "%" : ""
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Text {
        anchors.left: title.left
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: title.bottom
        anchors.topMargin: 1
        // У управляемого экрана здесь модель монитора, у остальных — почему
        // яркость недоступна: пользователю важно знать, что делать.
        text: root.controllable
              ? root.subtitle
              : (root.hint !== "" ? root.hint : "Not adjustable")
        elide: Text.ElideRight
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    PanelSlider {
        anchors.left: title.left
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 40
        height: 18
        visible: root.controllable
        value: root.value
        onMoved: v => root.moved(v)
    }
}
