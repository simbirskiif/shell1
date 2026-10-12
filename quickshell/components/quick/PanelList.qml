import QtQuick
import ".."
import "../../singletons"

// Список строк внутренней панели: заготовки анимаций появления, удаления
// и сдвига элементов. Высота считается по числу строк, а не по contentHeight:
// во время анимаций сдвига contentHeight меняется каждый кадр, и окно
// получало бы новую цель размера на каждом кадре — отсюда лаги.
ListView {
    id: root

    property real rowHeight: Theme.quickRowHeight
    // Высота, которую держим до конца анимации удаления, чтобы окно
    // не срезало гаснущую строку.
    property real frameHeight: 0

    readonly property real rowsHeight: root.count * root.rowHeight

    implicitHeight: Math.max(root.frameHeight, root.rowsHeight)
    height: implicitHeight
    interactive: false
    boundsBehavior: Flickable.StopAtBounds
    spacing: 0


    onRowsHeightChanged: {
        if (root.rowsHeight >= root.frameHeight)
            root.frameHeight = root.rowsHeight;
        else
            shrinkTimer.restart();
    }

    Timer {
        id: shrinkTimer
        interval: Theme.motionShort4
        onTriggered: root.frameHeight = root.rowsHeight
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
