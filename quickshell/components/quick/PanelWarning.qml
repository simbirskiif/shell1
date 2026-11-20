import QtQuick
import ".."
import "../../singletons"

// Плашка-предупреждение в духе M3 banner: тональный контейнер, иконка,
// заголовок, пояснение и текстовая кнопка действия. Занимает всю ширину,
// высоту считает по содержимому. Для «модуль целиком выключен» есть
// PanelDisabled — это другой случай.
Item {
    id: root

    required property string title
    property string description: ""
    property string actionText: ""
    property string icon: "\uf071"

    signal actionRequested()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: card.height + Theme.space.sm * 1.5

    Rectangle {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space.lg
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        height: body.implicitHeight + Theme.space.xl
        radius: Theme.shape.md
        color: Theme.withAlpha(Theme.warning, 0.12)

        Row {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.space.lg
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.md

            Text {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: Theme.warning
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.md
            }

            Column {
                id: texts
                width: body.width - mark.width - action.width
                       - (action.visible ? body.spacing : 0) - body.spacing
                spacing: 2

                Text {
                    width: parent.width
                    text: root.title
                    color: Theme.scheme.onSurface
                    font: Theme.typeLabelLarge
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.description !== ""
                    text: root.description
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodySmall
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                id: action
                anchors.verticalCenter: parent.verticalCenter
                visible: root.actionText !== ""
                width: visible ? actionLabel.implicitWidth + Theme.space.lg * 2 : 0
                height: 36
                radius: height / 2
                color: actionHover.hovered ? Theme.withAlpha(Theme.warning, 0.24)
                                           : Theme.withAlpha(Theme.warning, 0.14)
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: root.actionText
                    color: Theme.warning
                    font: Theme.typeLabelLarge
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
}
