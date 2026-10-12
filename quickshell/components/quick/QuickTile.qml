import QtQuick
import ".."
import "../../singletons"

// Плитка быстрых настроек: кружок слева переключает состояние,
// остальная площадь раскрывает панель управления.
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
    color: root.active ? Theme.quickTileActive
                       : (hover.hovered && !root.editable ? Theme.quickTileHover : Theme.quickTile)
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
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        interactive: !root.editable
        icon: root.icon
        active: root.active
        wifiStatus: root.wifiStatus
        onToggled: root.toggled()
    }

    Row {
        id: titleRow
        anchors.left: circle.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.subtitle !== ""
            text: "·"
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Text {
        anchors.left: titleRow.right
        anchors.leftMargin: titleRow.spacing
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.subtitle
        elide: Text.ElideRight
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
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
        color: removeHover.hovered ? Theme.lowColor : Theme.withAlpha(Theme.quickText, 0.18)
        z: 3
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            text: "\uf068"
            color: "#ffffff"
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
