import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import "../../singletons"

// Иконка приложения в компактной полосе дока. M3 navigation bar в миниатюре:
// круглая кнопка-цель, наведение — state layer поверх тональной карточки,
// запущенное приложение отмечено пилюлей primary под иконкой.
// Размер кнопки не меняется: увеличение при наведении — это transform,
// поэтому соседние иконки не едут.
Item {
    id: root

    required property var entry

    property int size: Theme.dockButtonSize
    property int iconSize: Theme.dockIconSize

    signal activated()

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property string iconSource: {
        if (!root.entry || !root.entry.icon)
            return "";
        return Quickshell.iconPath(root.entry.icon, true);
    }

    // Визуальный признак «приложение запущено»: id .desktop-файла сверяем
    // с appId/классом живых окон Hyprland. Это только состояние индикатора;
    // запуск приложения, сигналы и закрытие дока не меняются.
    readonly property bool running: {
        if (!root.entry || !root.entry.id)
            return false;
        // id .desktop-файла бывает и без суффикса, и с ним (org.telegram.desktop),
        // поэтому сверяем оба варианта с appId/классом окна.
        const rawId = String(root.entry.id).toLowerCase();
        const shortId = rawId.replace(/\.desktop$/, "");
        if (shortId.length === 0)
            return false;
        const windows = Hyprland.toplevels ? Hyprland.toplevels.values : null;
        if (!windows)
            return false;
        for (let i = 0; i < windows.length; ++i) {
            const window = windows[i];
            if (!window)
                continue;
            const appId = (window.wayland ? String(window.wayland.appId || "") : "").toLowerCase();
            const windowClass = (window.lastIpcObject
                ? String(window.lastIpcObject["class"] || "") : "").toLowerCase();
            if (appId === shortId || windowClass === shortId
                    || appId === rawId || windowClass === rawId)
                return true;
        }
        return false;
    }

    // Иконка и подложка «пружинят» при наведении; индикатор запуска живёт
    // отдельным слоем, поэтому не съезжает и не масштабируется вместе с ними.
    Item {
        id: content
        anchors.fill: parent

        scale: hover.pressed ? 0.94 : (hover.containsMouse ? 1.12 : 1)
        Behavior on scale {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveDockExpressive
            }
        }

        transform: Translate {
            y: hover.containsMouse && !hover.pressed ? -3 : 0
            Behavior on y {
                MotionNumber {
                    duration: Theme.motionShort3
                    curve: Theme.curveDockExpressive
                }
            }
        }

        // Подложка-состояние M3: в покое прозрачна, при наведении — state layer
        // onSurface поверх поверхности карточки (без произвольных цветов).
        Rectangle {
            anchors.fill: parent
            radius: Theme.shape.full
            color: Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
            opacity: hover.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }

        // Заглушка под иконкой: у части .desktop-файлов картинки нет.
        Text {
            anchors.centerIn: parent
            visible: iconImage.status !== Image.Ready
            text: root.entry && root.entry.name
                  ? String(root.entry.name).charAt(0).toUpperCase() : "?"
            color: Theme.scheme.onSurface
            font: Theme.typeTitleMedium
        }

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            source: root.iconSource
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }
    }

    // Индикатор запущенного приложения: пилюля M3 снизу, высотой 4 (space.xs).
    // Ширина анимируется, поэтому появление/исчезновение читается как в
    // navigation bar. Пилюля лежит внутри кнопки и иконку не перекрывает.
    Rectangle {
        id: activeIndicator
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.xs / 2
        height: Theme.space.xs
        width: root.running ? Theme.space.lg : 0
        radius: Theme.shape.full
        color: Theme.primary
        opacity: root.running ? 1 : 0
        Behavior on width {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveEmphasized
            }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
        onClicked: {
            DockState.keepAlive();
            root.activated();
            if (root.entry)
                root.entry.execute();
        }
    }
}
