import QtQuick
import Quickshell.Hyprland
import "../singletons"

// Рабочие столы текущего монитора в виде точек без номеров.
Item {
    id: root

    // Имя Wayland-выхода, на котором находится бар (ShellScreen.name).
    required property string screenName

    readonly property var workspaces: {
        const name = root.screenName;
        // id > 0 отсеивает special-воркспейсы, монитор — чужие экраны.
        return Hyprland.workspaces.values
            .filter(ws => ws.id > 0 && (!ws.monitor || ws.monitor.name === name))
            .sort((a, b) => a.id - b.id);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.workspaceSpacing

        Repeater {
            model: root.workspaces

            delegate: WorkspaceDot {
                required property var modelData
                workspace: modelData
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
