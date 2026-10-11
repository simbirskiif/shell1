import QtQuick
import "../../singletons"

// Список строк внутренней панели. Заготовки анимаций появления,
// удаления и сдвига элементов: высота списка следует за содержимым,
// поэтому окно попапа подстраивается вместе с ними.
ListView {
    id: root

    // Высота списка меняется не мгновенно: место под новый элемент нужно
    // сразу, а вот место удалённого отдаём только после его анимации —
    // иначе окно сжимается быстрее и обрезает гаснущую строку.
    property real frameHeight: 0

    implicitHeight: frameHeight
    height: implicitHeight
    interactive: false
    boundsBehavior: Flickable.StopAtBounds
    spacing: 0

    onContentHeightChanged: {
        if (contentHeight >= frameHeight)
            frameHeight = contentHeight;
        else
            shrinkTimer.restart();
    }

    Timer {
        id: shrinkTimer
        interval: Theme.quickViewDuration
        onTriggered: root.frameHeight = root.contentHeight
    }

    // Появление элемента: проявляется и дорастает.
    add: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.quickViewDuration
            easing.type: Theme.quickViewEasing
        }
        NumberAnimation {
            property: "scale"
            from: Theme.quickIdleScale
            to: 1
            duration: Theme.quickViewDuration
            easing.type: Theme.quickViewEasing
        }
    }

    // Удаление: элемент растворяется и сжимается.
    remove: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: Theme.quickViewDuration
            easing.type: Theme.quickViewEasing
        }
        NumberAnimation {
            property: "scale"
            to: Theme.quickIdleScale
            duration: Theme.quickViewDuration
            easing.type: Theme.quickViewEasing
        }
    }

    // Соседи переезжают на освободившееся или занятое место.
    displaced: Transition {
        NumberAnimation {
            property: "y"
            duration: Theme.quickWindowDuration
            easing.type: Theme.quickWindowEasing
        }
        NumberAnimation {
            property: "opacity"
            to: 1
            duration: Theme.quickViewDuration
        }
    }

    // Первичное заполнение — без анимации, чтобы список не «выплывал».
    populate: Transition {}
}
