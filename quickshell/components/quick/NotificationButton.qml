import QtQuick
import "../../singletons"

// Кнопка уведомлений в баре: колокольчик, точка непрочитанного и переход
// в Центр уведомлений. Форма и поведение — как у прочих кнопок оболочки.
Rectangle {
    id: root

    property bool opened: false

    signal clicked()

    implicitWidth: 30
    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: root.opened ? Theme.quickTileActive
                       : (hover.hovered ? Theme.quickTileHover : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: "\uf0f3"
        // Колокольчик не подсвечиваем: о непрочитанном говорит точка.
        color: Theme.quickText
        font.family: Theme.iconFontFamily
        font.pixelSize: 14
    }

    // Точка непрочитанного.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.top: parent.top
        anchors.topMargin: 5
        width: 7
        height: 7
        radius: width / 2
        visible: NotificationService.hasUnread
        color: Theme.lowColor
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
