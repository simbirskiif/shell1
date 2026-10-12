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

    signal backRequested()
    signal toggled()
    signal refreshRequested()

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

    ToggleSwitch {
        id: toggle
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        onToggled: root.toggled()
    }

    // Обновление списка: пока идёт поиск, значок вращается.
    Item {
        id: refreshButton
        anchors.right: toggle.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        visible: root.refreshable

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: refreshHover.hovered && !root.refreshing ? Theme.quickTileHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            id: refreshIcon
            anchors.centerIn: parent
            text: "\uf021"
            color: root.refreshing ? Theme.accent : Theme.quickText
            font.family: Theme.iconFontFamily
            font.pixelSize: 13
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        MouseArea {
            id: refreshHover
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.refreshing
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refreshRequested()
        }

        RotationAnimation on rotation {
            running: root.refreshing
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }

        Connections {
            target: root

            function onRefreshingChanged() {
                if (!root.refreshing)
                    refreshButton.rotation = 0;
            }
        }
    }
}
