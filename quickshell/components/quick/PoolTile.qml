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
    // Тональный контейнер m3: в покое — surface-container-high, на hover —
    // highest c состоянием поверх.
    color: hover.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
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
        anchors.verticalCenterOffset: -Theme.space.xs
        width: Theme.quickCircleSize
        height: Theme.quickCircleSize
        radius: Theme.shape.full
        color: Theme.surfaceContainerHighest

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
        }
    }

    // Подпись появляется только при наведении — в покое плитка «пустая».
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: circle.bottom
        anchors.topMargin: Theme.space.xs
        text: root.title
        color: Theme.scheme.onSurface
        font: Theme.typeLabelMedium
        opacity: hover.containsMouse ? 1 : 0
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveStandard
            }
        }
    }

    // «Плюс» крупнее и выступает за плитку: маленькая кнопка-иконка m3.
    Rectangle {
        id: addButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -Theme.space.xs
        anchors.topMargin: -Theme.space.xs
        width: Theme.iconSize.xl
        height: Theme.iconSize.xl
        radius: Theme.shape.full
        z: 3
        // Тональная подложка: state-layer on-surface, на hover — primary.
        color: addHover.containsMouse
               ? Theme.primary
               : Theme.stateLayer(Theme.scheme.onSurface, Theme.stateDragged)
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            text: "\uf067"
            color: addHover.containsMouse ? Theme.scheme.onPrimary : Theme.scheme.onSurface
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
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
