import QtQuick
import ".."
import "../../singletons"

// Плитка в пуле доступных: показывает только значок, подпись проявляется
// при наведении. «Плюс» в углу выходит за пределы плитки и возвращает
// её на панель.
Rectangle {
    id: root

    required property string icon
    required property string title

    // Управляется панелью: гасить/проявлять плитку в пуле.
    property bool shown: true

    signal addRequested()

    implicitWidth: Theme.quickWidth / 2
    implicitHeight: Theme.quickTileHeight
    radius: Theme.quickTileRadius
    color: hover.hovered ? Theme.quickTileHover : Theme.quickTile
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    Behavior on x {
        MotionNumber {
            duration: Theme.motionMedium1
            curve: Theme.curveEmphasized
        }
    }

    Behavior on y {
        MotionNumber {
            duration: Theme.motionMedium1
            curve: Theme.curveEmphasized
        }
    }

    Behavior on opacity {
        MotionNumber {
            duration: Theme.motionShort4
            curve: Theme.curveEmphasized
        }
    }

    Behavior on scale {
        MotionNumber {
            duration: Theme.motionMedium1
            curve: Theme.curveEmphasized
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addRequested()
    }

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -6
        width: Theme.quickCircleSize
        height: Theme.quickCircleSize
        radius: width / 2
        color: Theme.quickCircleOff

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 16
        }
    }

    // Подпись появляется только при наведении — в покое плитка «пустая».
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: circle.bottom
        anchors.topMargin: 4
        text: root.title
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 11
        opacity: hover.hovered ? 1 : 0
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveStandard
            }
        }
    }

    // «Плюс» крупнее и выступает за плитку.
    Rectangle {
        id: addButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -6
        anchors.topMargin: -6
        width: 26
        height: 26
        radius: width / 2
        z: 3
        color: addHover.hovered ? Theme.accent : Theme.withAlpha(Theme.quickText, 0.18)
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            text: "\uf067"
            color: addHover.hovered ? Theme.quickIconOn : Theme.quickText
            font.family: Theme.iconFontFamily
            font.pixelSize: 11
        }

        MouseArea {
            id: addHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.addRequested()
        }
    }
}
