import QtQuick
import "../../singletons"

// Содержимое раскрытого дока: список приложений. Это «большая панель»,
// в которую плавно превращается компактная полоса.
Item {
    id: root

    required property string screenName

    signal closeRequested()
    signal quickSettingsRequested()

    // Шапка остаётся на месте, сетка прокручивается: приложение можно
    // найти, даже если панель ниже полного списка.
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34

        Text {
            id: titleText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Приложения"
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: titleText.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: DockApps.all.length > 0
            text: "· " + DockApps.all.length
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: header.verticalCenter
        spacing: 2

        DockIconButton {
            size: 34
            glyphSize: 14
            icon: "\uf013"

            onClicked: root.quickSettingsRequested()
        }

        DockIconButton {
            size: 34
            glyphSize: 14
            icon: "\uf00d"

            onClicked: root.closeRequested()
        }
    }

    GridView {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: width / Theme.dockGridColumns
        cellHeight: Theme.dockGridCellHeight
        model: DockApps.all

        delegate: DockGridApp {
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight
            entry: modelData
            onActivated: DockState.hide()
        }
    }

    Text {
        anchors.centerIn: parent
        visible: DockApps.all.length === 0
        text: "Список приложений пуст"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
