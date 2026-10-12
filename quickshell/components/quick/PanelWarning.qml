import QtQuick
import ".."
import "../../singletons"

// Компактная плашка-предупреждение внутри панели: иконка, заголовок,
// пояснение и необязательная кнопка действия. Занимает всю ширину панели,
// высоту считает по содержимому. Для «модуль целиком выключен» есть
// PanelDisabled — это другой случай: здесь предупреждение живёт рядом с
// остальным содержимым, на месте недоступного блока.
Item {
    id: root

    required property string title
    property string description: ""
    property string actionText: ""
    property string icon: "\uf071"

    signal actionRequested()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: card.height + 20

    Rectangle {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        height: body.implicitHeight + 24
        radius: Theme.quickTileRadius
        color: Theme.withAlpha(Theme.warningColor, 0.10)
        border.width: 1
        border.color: Theme.withAlpha(Theme.warningColor, 0.28)

        Row {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: Theme.warningColor
                font.family: Theme.iconFontFamily
                font.pixelSize: 16
            }

            Column {
                id: texts
                width: body.width - mark.width - action.width
                       - (action.visible ? body.spacing : 0) - body.spacing
                spacing: 2

                Text {
                    width: parent.width
                    text: root.title
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.description !== ""
                    text: root.description
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                id: action
                anchors.verticalCenter: parent.verticalCenter
                visible: root.actionText !== ""
                width: visible ? actionLabel.implicitWidth + 26 : 0
                height: 28
                radius: height / 2
                color: actionHover.hovered ? Theme.withAlpha(Theme.warningColor, 0.24)
                                           : Theme.withAlpha(Theme.warningColor, 0.14)
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: root.actionText
                    color: Theme.warningColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
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
