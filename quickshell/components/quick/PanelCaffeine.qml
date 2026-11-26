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
            title: I18n.tr("quick.tile.caffeine")
            checked: CaffeineService.active
            onBackRequested: root.backRequested()
            onToggled: CaffeineService.toggle()
        }

        // Разделитель шапки m3 — outline-variant.
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PanelList {
            width: parent.width
            model: CaffeineService.options

            delegate: Item {
                id: modeRow

                required property var modelData

                readonly property bool current: CaffeineService.mode === modelData.key
                // m3 divider между строками: у последней строки списка нет.
                readonly property bool separatorVisible: ListView.view !== null
                    && (modeRow.y + modeRow.height) < ListView.view.contentHeight

                width: parent.width
                height: Theme.listItemHeight

                // Строка списка m3: прозрачный контейнер, hover — state layer.
                Rectangle {
                    anchors.fill: parent
                    color: modeHover.containsMouse
                           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    id: modeLabel
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.lg
                    anchors.right: checkMark.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title
                    elide: Text.ElideRight
                    color: modeRow.current ? Theme.primary : Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                }

                Text {
                    id: checkMark
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modeRow.current
                    text: "\uf00c"
                    color: Theme.primary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                // Разделитель m3: outline-variant, толщина 1, отступ 16.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.space.lg
                    height: 1
                    color: Theme.outlineVariant
                    visible: modeRow.separatorVisible
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
