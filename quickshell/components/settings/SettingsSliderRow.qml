import QtQuick
import "../../singletons"
import "../quick"

// Строка с ползунком: слева название и подпись, справа дорожка и значение.
// Значение ползунка нормировано 0..1; перевод в реальные единицы делает
// вызывающая страница через сигнал moved.
SettingsRow {
    id: root

    required property real value
    property string valueText: ""

    signal moved(real v)

    Item {
        width: Math.min(240, Math.max(140, root.width * 0.42))
        height: Theme.touchTarget

        PanelSlider {
            id: slider

            anchors.left: parent.left
            anchors.right: valueLabel.left
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            value: root.value
            onMoved: v => root.moved(v)
        }

        Text {
            id: valueLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: root.valueText
            color: Theme.primary
            font: Theme.typeLabelLarge
        }
    }
}
