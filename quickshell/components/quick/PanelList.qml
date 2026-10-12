import QtQuick
import ".."
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

    implicitHeight: Math.max(frameHeight, contentHeight)
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
        interval: Theme.motionShort4
        onTriggered: root.frameHeight = root.contentHeight
    }

    // m3 enter: элемент проявляется и дорастает с 80%.
    add: Transition {
        MotionNumber {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.motionMedium1
            curve: Theme.curveEmphasizedDecelerate
        }
        MotionNumber {
            property: "scale"
            from: Theme.motionElementScale
            to: 1
            duration: Theme.motionMedium1
            curve: Theme.curveEmphasizedDecelerate
        }
    }

    // m3 exit: элемент растворяется и сжимается.
    remove: Transition {
        MotionNumber {
            property: "opacity"
            to: 0
            duration: Theme.motionShort4
            curve: Theme.curveEmphasizedAccelerate
        }
        MotionNumber {
            property: "scale"
            to: Theme.motionElementScale
            duration: Theme.motionShort4
            curve: Theme.curveEmphasizedAccelerate
        }
    }

    // Соседи переезжают на освободившееся или занятое место.
    displaced: Transition {
        MotionNumber {
            property: "y"
            duration: Theme.motionMedium1
            curve: Theme.curveEmphasized
        }
        MotionNumber {
            property: "opacity"
            to: 1
            duration: Theme.motionShort4
            curve: Theme.curveStandard
        }
    }

    // Первичное заполнение — без анимации, чтобы список не «выплывал».
    populate: Transition {}
}
