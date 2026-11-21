import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import "../expressive"
import "../../singletons"

// Иконка приложения в компактной полосе дока.
//
// Expressive: кнопка — не «кружок с подсветкой», а живая форма. Запущенное
// приложение получает крупную подложку-«печенье»/«солнышко» в контейнерном
// цвете (primary/tertiary чередуются по ряду), при наведении форма морфится
// в клевер и иконка упруго подрастает, при нажатии — сжимается в squircle.
// Индикатор запуска — волнистая пилюля на spatial-пружине, отдельным слоем:
// она не масштабируется вместе с иконкой и не съезжает.
Item {
    id: root

    required property var entry

    property int size: Theme.dockButtonSize
    property int iconSize: Theme.dockIconSize
    // Акцент подложки: primary и tertiary чередуются, чтобы ряд читался как
    // набор выразительных форм, а не как один цвет.
    property string accent: "primary"
    // Порядковый номер в ряду: от него зависит пара «цвет + форма».
    property int slot: 0

    signal activated()

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property bool hovered: hover.containsMouse
    readonly property bool pressed: hover.pressed

    // Иконка не забивает воздух кнопки: настройка размера работает в
    // пределах свободного места (24–28 при кнопке 48–52).
    readonly property real glyphSize: Math.max(20, Math.min(root.iconSize,
                                                             root.size - 24))
    // Чётные и нечётные приложения получают разные контуры: cookie и sunny
    // соседствуют, поэтому ряд сразу читается как expressive, а не как сетка.
    readonly property string restShape: root.slot % 2 === 0 ? "cookie" : "sunny"

    readonly property color accentContainer: root.accent === "tertiary" ? Theme.tertiaryContainer
                                           : root.accent === "secondary" ? Theme.secondaryContainer
                                           : Theme.primaryContainer
    readonly property color accentInk: root.accent === "tertiary" ? Theme.scheme.onTertiaryContainer
                                     : root.accent === "secondary" ? Theme.scheme.onSecondaryContainer
                                     : Theme.scheme.onPrimaryContainer
    // Индикатор запуска — контрастный к подложке, иначе сливается с ней.
    readonly property color indicatorColor: root.accent === "primary" ? Theme.tertiary
                                                                     : Theme.primary

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

        // Нажатие сжимает, наведение — упруго раздувает. Размер кнопки при
        // этом не меняется: увеличение — transform, соседние иконки не едут.
        scale: root.pressed ? 0.9 : (root.hovered ? 1.12 : 1)
        Behavior on scale { SpringSpatial {} }

        transform: Translate {
            y: root.hovered && !root.pressed ? -2 : 0
            Behavior on y { SpringSpatial {} }
        }

        // Подложка-форма: у запущенного приложения — контейнерный цвет и
        // выразительный контур, у наведения на неактивное — squircle
        // тональной поверхности. В покое у неактивного подложки нет.
        MorphShape {
            id: backdrop
            anchors.centerIn: parent
            width: Math.round(root.size * 0.86)
            height: width
            shape: root.pressed ? "squircle"
                 : root.running ? (root.hovered ? "clover" : root.restShape)
                 : (root.hovered ? "squircle" : "circle")
            modulation: 0.8
            color: root.running ? root.accentContainer
                 : root.hovered ? Theme.surfaceContainerHighest
                 : "transparent"

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        // Заглушка под иконкой: у части .desktop-файлов картинки нет.
        Text {
            anchors.centerIn: parent
            visible: iconImage.status !== Image.Ready
            text: root.entry && root.entry.name
                  ? String(root.entry.name).charAt(0).toUpperCase() : "?"
            color: root.running ? root.accentInk : Theme.scheme.onSurface
            font: Theme.typeTitleMedium
        }

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: root.glyphSize
            height: root.glyphSize
            source: root.iconSource
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }
    }

    readonly property string iconSource: {
        if (!root.entry || !root.entry.icon)
            return "";
        return Quickshell.iconPath(root.entry.icon, true);
    }

    // Индикатор запущенного приложения: волнистая пилюля снизу, которая
    // растягивается на spatial-пружине. Лежит вне content, поэтому не
    // масштабируется вместе с иконкой и остаётся «точкой отсчёта».
    MorphShape {
        id: activeIndicator
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: 6
        width: root.running ? 18 : 6
        shape: "pill"
        modulation: 0.9
        color: root.indicatorColor
        opacity: root.running ? 1 : 0
        Behavior on width { SpringSpatial {} }
        Behavior on opacity { SpringEffects {} }
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
