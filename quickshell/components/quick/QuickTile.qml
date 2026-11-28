import QtQuick
import ".."
import "../../singletons"

// Плитка быстрых настроек в духе Material 3: тональный контейнер,
// круглая иконка-переключатель слева, двухстрочная подпись справа.
// Кружок переключает состояние, остальная площадь раскрывает панель.
// В режиме редактирования плитка чуть уменьшается (визуально, размеры в
// раскладке не меняются), сверху справа появляется «минус», а перетаскивание
// меняет порядок плиток.
Rectangle {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    required property bool active
    // Плитка Wi-Fi: в кружке деления сигнала вместо обычного глифа.
    property bool wifiStatus: false

    property bool editable: false
    // Показывать ли плитку: скрытая гаснет на месте, а не улетает в угол.
    property bool shown: true
    // Позиция в сетке (её задаёт панель) — нужна для перетаскивания.
    property int order: -1
    property int columns: 2
    property real stepX: width
    property real stepY: height

    signal toggled()
    signal expandRequested()
    signal removeRequested()
    signal reorderRequested(int from, int to)

    implicitWidth: Theme.quickWidth / 2
    implicitHeight: Theme.quickTileHeight
    radius: Theme.quickTileRadius
    color: root.active ? Theme.blurInnerCard(Theme.secondaryContainer)
                       : Theme.blurInnerCard(Theme.surfaceContainerHigh)
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    // В редакторе плитка выглядит меньше, но место занимает то же.
    // Скрытая плитка уходит по m3 exit: растворяется и сжимается.
    scale: (root.editable ? 0.92 : 1) * (root.shown ? 1 : Theme.motionElementScale)
    Behavior on scale {
        MotionNumber {
            duration: Theme.motionMedium1
            curve: Theme.curveEmphasized
        }
    }

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

    // Слой состояния M3: наведение подсвечивает плитку поверх тона.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.stateLayer(root.active ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface, Theme.stateHover)
        opacity: hover.containsMouse && !root.editable ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: !root.editable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expandRequested()
    }

    StatusCircle {
        id: circle
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        interactive: !root.editable
        icon: root.icon
        active: root.active
        wifiStatus: root.wifiStatus
        onToggled: root.toggled()
    }

    Column {
        id: texts
        anchors.left: circle.right
        anchors.leftMargin: Theme.space.md
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            width: parent.width
            text: root.title
            color: root.active ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
            font: Theme.typeLabelLarge
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: root.active ? Theme.withAlpha(Theme.scheme.onSecondaryContainer, 0.8)
                               : Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelMedium
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }
    }

    // Перетаскивание в редакторе: меняем порядок, когда курсор уходит
    // в другую ячейку сетки.
    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.editable
        preventStealing: true
        cursorShape: Qt.DragMoveCursor

        onPositionChanged: mouse => {
            if (!pressed || root.order < 0)
                return;
            const baseX = (root.order % root.columns) * root.stepX;
            const baseY = Math.floor(root.order / root.columns) * root.stepY;
            const col = Math.max(0, Math.min(root.columns - 1, Math.floor((baseX + mouse.x) / root.stepX)));
            const row = Math.max(0, Math.floor((baseY + mouse.y) / root.stepY));
            const target = row * root.columns + col;
            if (target !== root.order)
                root.reorderRequested(root.order, target);
        }
    }

    // «Минус» в правом верхнем углу — убрать плитку в доступные.
    Rectangle {
        id: removeButton
        visible: root.editable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -6
        anchors.topMargin: -6
        width: 26
        height: 26
        radius: width / 2
        color: removeHover.containsMouse ? Theme.error : Theme.errorContainer
        border.width: 2
        border.color: Theme.surface
        z: 3
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            text: "\uf068"
            color: removeHover.containsMouse ? Theme.scheme.onError : Theme.scheme.onErrorContainer
            font.family: Theme.iconFontFamily
            font.pixelSize: 10
        }

        MouseArea {
            id: removeHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeRequested()
        }
    }
}
