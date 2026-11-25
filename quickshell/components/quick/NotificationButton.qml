import QtQuick
import "../../singletons"

// Кнопка уведомлений в баре: колокольчик, точка непрочитанного и переход
// в Центр уведомлений. Форма и поведение — как у прочих кнопок оболочки.
Rectangle {
    id: root

    property bool opened: false
    // Иконка по умолчанию — колокольчик; в настройках бара её можно сменить.
    property string iconGlyph: "\uf0f3"

    signal clicked()

    implicitWidth: Theme.iconButtonSize
    implicitHeight: Theme.iconButtonSize
    radius: Theme.controlRadius
    color: root.opened ? Theme.secondaryContainer
                       : (hover.containsMouse ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                                        : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: root.iconGlyph
        // Колокольчик не подсвечиваем: о непрочитанном говорит точка.
        color: root.opened ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.sm
    }

    // Точка непрочитанного.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.top: parent.top
        anchors.topMargin: 5
        width: 8
        height: 8
        radius: width / 2
        visible: NotificationService.hasUnread
        color: Theme.error
        border.width: 1.5
        border.color: Theme.barBackground
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
