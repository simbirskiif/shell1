import QtQuick
import ".."
import "../../singletons"

// Вкладки панели: равные сегменты с подписью и подчёркиванием под активной
// (m3 primary tabs). Компонент «глупый»: список вкладок [{ key, title }] и
// текущий ключ приходят снаружи, наружу уходит выбранный ключ. Так одна
// панель («Звук») может разделить вывод и вход на два независимых экрана.
Item {
    id: root

    required property var tabs
    required property string current

    signal selected(string key)

    readonly property int tabCount: root.tabs.length
    readonly property real tabWidth: root.tabCount > 0 ? width / root.tabCount : width

    readonly property int currentIndex: {
        for (let i = 0; i < root.tabs.length; ++i) {
            if (root.tabs[i].key === root.current)
                return i;
        }
        return 0;
    }

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.touchTarget
    height: implicitHeight

    Repeater {
        model: root.tabs

        delegate: Item {
            required property var modelData
            required property int index

            readonly property bool active: modelData.key === root.current

            x: index * root.tabWidth
            width: root.tabWidth
            height: root.height

            // Состояние m3: hover — state layer on-surface поверх вкладки.
            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.space.xs
                radius: Theme.shape.xs
                color: Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                opacity: tabHover.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
            }

            Text {
                anchors.centerIn: parent
                text: modelData.title
                color: parent.active ? Theme.primary : Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelLarge
                Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            }

            MouseArea {
                id: tabHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(modelData.key)
            }
        }
    }

    // Линия на всю ширину и поверх неё — индикатор активной вкладки.
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.outlineVariant
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: root.tabWidth
        height: 3
        radius: height / 2
        color: Theme.primary
        x: root.currentIndex * root.tabWidth
        Behavior on x {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasized
            }
        }
    }
}
