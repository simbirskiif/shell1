import QtQuick
import "../../singletons"
import "../core"

// Карточка состояния вместо контента виджета: ошибка загрузки QML или
// «виджет недоступен». Ужимается до размера маленькой клетки: в компактном
// режиме остаются иконка, имя и кнопки-символы.
Item {
    id: root

    property string icon: "⚠"
    property string title: ""
    property string message: ""
    property bool showReload: true

    signal reloadRequested()
    signal deleteRequested()

    readonly property bool compact: width < 120 || height < 110

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width, root.compact ? parent.width : 220)
        spacing: root.compact ? 2 : 6

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.colors.error
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? 12 : 16
            text: root.icon
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? 9 : 12
            font.bold: true
            elide: Text.ElideRight
            text: root.title
        }

        Text {
            width: parent.width
            visible: !root.compact && root.message.length > 0
            horizontalAlignment: Text.AlignHCenter
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: root.message
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            HostButton {
                text: root.compact ? "↻" : "Перезагрузить"
                visible: root.showReload
                onClicked: root.reloadRequested()
            }

            HostButton {
                text: root.compact ? "✕" : "Удалить"
                onClicked: root.deleteRequested()
            }
        }
    }
}
