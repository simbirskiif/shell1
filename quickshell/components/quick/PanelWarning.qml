import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Плашка-предупреждение в духе Expressive: крупная форма-«осколок» с
// иконкой, заголовок typeEmphasizedTitleMedium, пояснение bodyMedium и
// кнопка-пилюля действия. Занимает всю ширину, высоту считает по
// содержимому. Для «модуль целиком выключен» есть PanelDisabled — это
// другой случай. Тонких рамок нет: контейнер держится цветом и формой.
Item {
    id: root

    required property string title
    property string description: ""
    property string actionText: ""
    property string icon: "\uf071"

    signal actionRequested()

    readonly property bool actionHovered: actionHover.containsMouse
    readonly property bool actionPressed: actionHover.pressed

    implicitWidth: parent ? parent.width : 0
    implicitHeight: card.height + Theme.space.sm * 1.5

    MorphShape {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space.md
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        height: body.implicitHeight + Theme.space.lg
        shape: "squircle"
        color: Theme.withAlpha(Theme.warning, 0.16)
        modulation: 0.4
    }

    Row {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space.lg
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.md

        // Орб-«осколок»: у предупреждения форма burst, а не ровный круг.
        MorphShape {
            id: mark
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            shape: "burst"
            color: Theme.withAlpha(Theme.warning, 0.28)
            modulation: 0.8

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: Theme.warning
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.md
            }
        }

        Column {
            id: texts
            width: body.width - mark.width - action.width
                   - (action.visible ? body.spacing : 0) - body.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.title
                color: Theme.scheme.onSurface
                font: Theme.typeEmphasizedTitleLarge
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.description !== ""
                text: root.description
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodyMedium
                wrapMode: Text.WordWrap
            }
        }

        // Кнопка действия — пилюля warning-контейнера; на hover темнее,
        // нажатие сжимает пружиной.
        Item {
            id: action
            anchors.verticalCenter: parent.verticalCenter
            visible: root.actionText !== ""
            width: visible ? actionLabel.implicitWidth + Theme.space.lg * 2 : 0
            height: 44
            scale: root.actionPressed ? 0.94 : (root.actionHovered ? 1.04 : 1)

            Behavior on scale { SpringSpatialFast {} }

            MorphShape {
                anchors.fill: parent
                shape: root.actionHovered ? "squircle" : "pill"
                color: root.actionHovered ? Theme.withAlpha(Theme.warning, 0.28)
                                          : Theme.withAlpha(Theme.warning, 0.16)
                modulation: 0.4

                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: root.actionText
                color: Theme.warning
                font: Theme.typeEmphasizedLabelLarge
            }

            MouseArea {
                id: actionHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionRequested()
            }
        }
    }
}
