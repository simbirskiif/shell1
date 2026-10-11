import QtQuick
import "../../singletons"

// Единая обёртка вида (основная панель и дочерние панели): неактивный
// вид растворяется и уменьшается, активный проявляется и растёт.
// Работает вместе с анимацией размера окна в QuickPopup.
Item {
    id: root

    required property bool active

    default property alias content: host.data

    readonly property Item view: host.children.length > 0 ? host.children[0] : null

    implicitWidth: view ? view.implicitWidth : 0
    implicitHeight: view ? view.implicitHeight : 0

    opacity: active ? 1 : 0
    scale: active ? 1 : Theme.quickIdleScale
    transformOrigin: Item.Top
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.quickViewDuration
            easing.type: Theme.quickViewEasing
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.quickViewDuration
            easing.type: Theme.quickViewEasing
        }
    }

    Item {
        id: host
        anchors.fill: parent
    }
}
