import QtQuick
import Quickshell
import Quickshell.Wayland
import "../singletons"

// Верхний бар: слева рабочие столы, по центру дата и время.
// Правая секция пока пустая.
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: Theme.barBackground
    exclusiveZone: Theme.barHeight
    WlrLayershell.namespace: "quickshell-bar"

    Workspaces {
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter
        screenName: root.screen ? root.screen.name : ""
    }

    Clock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
    }
}
