import QtQuick
import ".."
import "../../singletons"

// Шапка внутренней панели: кнопка «назад», название, при необходимости
// кнопка обновления списка и переключатель.
Item {
    id: root

    required property string title
    required property bool checked
    property bool refreshable: false
    property bool refreshing: false
    // Дополнительное действие (например, режим обнаружения).
    property string actionIcon: ""
    property bool actionChecked: false
    // У некоторых панелей (например «Питание») тумблера нет.
    property bool switchable: true

    signal backRequested()
    signal toggled()
    signal refreshRequested()
    signal actionRequested()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.quickHeaderHeight
    height: implicitHeight

    Rectangle {
        id: backButton
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: width / 2
        color: backHover.hovered ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            text: "\uf053"
            color: Theme.quickText
            font.family: Theme.iconFontFamily
            font.pixelSize: 12
        }

        MouseArea {
            id: backHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
        }
    }

    Text {
        anchors.left: backButton.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    // Правая группа: действие, обновление, переключатель.
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Item {
            id: actionButton
            width: root.actionIcon !== "" ? 30 : 0
            height: 30
            visible: width > 0

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.actionChecked ? Theme.quickTileActive
                                          : (actionHover.hovered ? Theme.quickTileHover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            Text {
                anchors.centerIn: parent
                text: root.actionIcon
                color: root.actionChecked ? Theme.accent : Theme.quickText
                font.family: Theme.iconFontFamily
                font.pixelSize: 13
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            MouseArea {
                id: actionHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionRequested()
            }
        }

        Item {
            id: refreshButton
            width: root.refreshable ? 30 : 0
            height: 30
            visible: width > 0

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: refreshHover.hovered && !root.refreshing ? Theme.quickTileHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            // Пока идёт поиск — вместо значка обновления крутится индикатор.
            Text {
                id: refreshIcon
                anchors.centerIn: parent
                visible: !root.refreshing
                text: "\uf021"
                color: Theme.quickText
                font.family: Theme.iconFontFamily
                font.pixelSize: 13
            }

            LoadingIndicator {
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: root.refreshing
            }

            MouseArea {
                id: refreshHover
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.refreshing
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refreshRequested()
            }
        }

        ToggleSwitch {
            id: toggle
            width: root.switchable ? 42 : 0
            visible: width > 0
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            onToggled: root.toggled()
        }
    }
}
