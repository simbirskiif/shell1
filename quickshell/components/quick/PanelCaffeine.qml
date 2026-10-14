import QtQuick
import ".."
import "../../singletons"

// Панель «Кофеин»: выбор срока — из настроенных длительностей и бесконечного.
// Пункта «выключен» здесь нет: выключение делает переключатель в шапке или
// кружок плитки.
Item {
    id: root

    signal backRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: "Кофеин"
            checked: CaffeineService.active
            onBackRequested: root.backRequested()
            onToggled: CaffeineService.toggle()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        PanelList {
            width: parent.width
            model: CaffeineService.options

            delegate: Item {
                required property var modelData

                readonly property bool current: CaffeineService.mode === modelData.key

                width: parent.width
                height: Theme.quickRowHeight

                Rectangle {
                    anchors.fill: parent
                    color: modeHover.hovered ? Theme.quickTileHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    id: modeLabel
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: checkMark.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title
                    elide: Text.ElideRight
                    color: current ? Theme.accent : Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                }

                Text {
                    id: checkMark
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: current
                    text: "\uf00c"
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 13
                }

                MouseArea {
                    id: modeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CaffeineService.setMode(modelData.key)
                }
            }
        }
    }
}
