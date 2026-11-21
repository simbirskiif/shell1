import QtQuick
import Quickshell
import "../expressive"
import "../../singletons"

// Результат поиска в двух видах: строка и плитка. Высота задаётся
// GridView, поэтому переходы add/remove/displaced работают в обоих видах.
// Мышь выбирает элемент только при реальном входе/движении указателя.
//
// Expressive: карточки-плитки — контрастные контейнеры (primary/tertiary/
// secondary) с чередующимися формами squircle/cookie/pill; выбранная
// карточка — secondary-container и форма clover. Строки — крупные пилюли
// с воздухом между ними (разделителей нет): в покое прозрачные, при
// наведении — squircle тональной поверхности, выбранная — cookie на
// secondary-container. Иконка живёт в орбе 42, глиф — 24.
Item {
    id: root

    required property var item
    property bool tile: false
    // Порядковый номер в выдаче: чередует контейнеры и формы плиток,
    // поэтому сетка выглядит как набор разных фигур, а не как один цвет.
    property int slot: 0
    // Индекс делегата: нужен и для выбора по мыши (GridView.currentIndex).
    required property int index

    signal activated()

    width: GridView.view ? GridView.view.cellWidth : 0
    height: GridView.view ? GridView.view.cellHeight : 44
    scale: 1
    opacity: 1

    // Текущий элемент списка: в плитках он получает clover на
    // secondary-container, в строках — cookie на secondary-container.
    readonly property bool current: GridView.isCurrentItem
    readonly property bool hovered: hover.containsMouse
    readonly property bool pressed: hover.pressed

    readonly property string iconSource: {
        if (!root.item || !root.item.icon)
            return "";
        return Quickshell.iconPath(root.item.icon, true);
    }

    // Цвет и форма плитки чередуются по номеру: primary-container/squircle,
    // tertiary-container/cookie, secondary-container/pill. Выбранная плитка
    // всегда secondary-container + clover — форма важнее цвета, поэтому
    // выбор читается даже там, где контейнер совпадает.
    readonly property int toneIndex: root.slot % 3
    readonly property color tileContainer: root.current ? Theme.secondaryContainer
        : root.toneIndex === 0 ? Theme.primaryContainer
        : root.toneIndex === 1 ? Theme.tertiaryContainer
        : Theme.secondaryContainer
    readonly property color tileInk: root.current ? Theme.scheme.onSecondaryContainer
        : root.toneIndex === 0 ? Theme.scheme.onPrimaryContainer
        : root.toneIndex === 1 ? Theme.scheme.onTertiaryContainer
        : Theme.scheme.onSecondaryContainer
    readonly property string tileShape: root.current ? "clover"
        : root.toneIndex === 0 ? "squircle"
        : root.toneIndex === 1 ? "cookie"
        : "pill"

    // Строка: выбранная — secondary-container + cookie, наведение —
    // squircle тональной поверхности, в покое формы нет.
    readonly property color rowColor: root.current ? Theme.secondaryContainer
        : root.hovered ? Theme.surfaceContainerHigh
        : "transparent"
    readonly property color rowInk: root.current ? Theme.scheme.onSecondaryContainer
                                                 : Theme.scheme.onSurface

    function activate() {
        root.activated();
        if (root.item)
            DockSearch.activate(root.item);
    }

    // Всё содержимое в одном слое: hover/press масштабируют форму и текст,
    // а root.scale остаётся свободным для переходов GridView.
    Item {
        id: content
        anchors.fill: parent

        scale: root.pressed ? 0.97
             : (root.tile && root.hovered ? 1.03 : 1)
        Behavior on scale { SpringSpatialFast {} }

        // --- форма-контейнер ------------------------------------------
        // Плитка — MorphShape: контейнер почти квадратный, поэтому
        // полярный контур читается как настоящая фигура (squircle/cookie/
        // pill, выбранная — clover).
        MorphShape {
            id: tileCard
            visible: root.tile
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, root.width - Theme.space.xs)
            height: Math.max(0, root.height - Theme.space.xs)
            shape: root.pressed ? "squircle" : root.tileShape
            modulation: root.current ? 0.45 : 0.5
            color: Theme.mix(root.tileContainer, root.tileInk,
                             root.pressed ? 0.10 : (root.hovered ? 0.06 : 0))
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        // Строка — stadium, а не MorphShape: полярная форма на широкой
        // строке вытягивается в «линзу» с острыми концами. Выразительность
        // строки держит cookie-орб, а контейнер остаётся ровной пилюлей.
        Rectangle {
            id: rowCard
            visible: !root.tile
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: root.width
            height: Math.max(0, root.height - Theme.space.xs)
            radius: height / 2
            color: root.rowColor
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        // --- строковый вид --------------------------------------------
        // Орб иконки: у выбранной строки — tertiary-container, иначе
        // тональная поверхность. Контейнер строки и орб — разные роли,
        // поэтому строка читается как «содержимое в форме», а не плашка.
        MorphShape {
            id: rowOrb
            visible: !root.tile
            anchors.left: parent.left
            anchors.leftMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            shape: root.current ? "cookie" : (root.hovered ? "sunny" : "circle")
            modulation: 0.9
            color: root.current ? Theme.tertiaryContainer : Theme.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Image {
            id: iconImage
            visible: !root.tile
            anchors.centerIn: rowOrb
            width: Theme.iconSize.lg
            height: width
            source: root.iconSource
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }

        Text {
            anchors.centerIn: rowOrb
            visible: !root.tile && iconImage.status !== Image.Ready
            text: root.item && root.item.title
                  ? String(root.item.title).charAt(0).toUpperCase() : "?"
            color: root.rowInk
            font: Theme.typeTitleMedium
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Column {
            visible: !root.tile
            anchors.left: rowOrb.right
            anchors.leftMargin: Theme.space.md
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.lg
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: root.item ? root.item.title : ""
                color: root.rowInk
                font: root.current ? Theme.typeEmphasizedLabelLarge : Theme.typeBodyLarge
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Text {
                width: parent.width
                visible: root.item && root.item.subtitle !== ""
                text: root.item ? root.item.subtitle : ""
                color: root.current ? Theme.withAlpha(Theme.scheme.onSecondaryContainer, 0.8)
                                    : Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelMedium
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }

        // --- плиточный вид --------------------------------------------
        // Орб под иконкой: полупрозрачная ink-подложка, поэтому глиф
        // читается на любом из трёх контейнеров.
        MorphShape {
            id: tileOrb
            visible: root.tile
            anchors.horizontalCenter: parent.horizontalCenter
            width: 46
            height: 46
            anchors.top: parent.top
            anchors.topMargin: Theme.space.sm
            shape: root.current ? "sunny" : "circle"
            modulation: 0.9
            color: Theme.withAlpha(root.tileInk, 0.14)
        }

        Image {
            id: tileIcon
            visible: root.tile
            anchors.centerIn: tileOrb
            width: Theme.iconSize.lg + Theme.space.xs
            height: width
            source: root.iconSource
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }

        Text {
            anchors.centerIn: tileOrb
            visible: root.tile && tileIcon.status !== Image.Ready
            text: root.item && root.item.title
                  ? String(root.item.title).charAt(0).toUpperCase() : "?"
            color: root.tileInk
            font: Theme.typeTitleMedium
        }

        Text {
            visible: root.tile
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.space.sm
            anchors.rightMargin: Theme.space.sm
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space.sm
            text: root.item ? root.item.title : ""
            color: root.tileInk
            font: Theme.typeLabelMedium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onContainsMouseChanged: if (containsMouse) DockState.keepAlive()

        // Мышь — второй приоритет: наведение меняет выделение только
        // после реального появления курсора на элементе. Неподвижный
        // указатель, под которым появилась панель, ничего не выбирает.
        onEntered: {
            if (Date.now() < DockState.mouseGuardUntil)
                return;
            // Курсор не двигался — значит под ним просто переехал список.
            if (Date.now() - DockState.pointerMovedAt > 150)
                return;
            if (GridView.view && GridView.view.currentIndex !== root.index)
                GridView.view.currentIndex = root.index;
        }

        onPositionChanged: {
            if (Date.now() < DockState.mouseGuardUntil)
                return;
            // Тот же фильтр, что и на входе: позиция могла измениться
            // потому, что под неподвижным курсором переехал список.
            if (Date.now() - DockState.pointerMovedAt > 150)
                return;
            if (GridView.view && GridView.view.currentIndex !== root.index)
                GridView.view.currentIndex = root.index;
        }

        onClicked: {
            if (GridView.view)
                GridView.view.currentIndex = root.index;
            root.activate();
            DockState.hide();
        }
    }
}
