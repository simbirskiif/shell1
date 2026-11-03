import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../singletons"

// Alt+Tab: горизонтальная лента окон с иконками, как в Windows.
// Список — WindowState (порядок MRU), активация — focus по адресу.
PanelWindow {
    id: root

    required property ShellScreen pickerScreen

    readonly property string screenName: pickerScreen ? pickerScreen.name : ""
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property bool onFocusedScreen: focusedScreenName === ""
                                             || focusedScreenName === root.screenName

    readonly property int cardWidth: 136
    readonly property int cardHeight: 148
    readonly property int cardSpacing: 10
    readonly property int maxRowWidth: pickerScreen ? pickerScreen.width - 140 : 1000
    readonly property int rowWidth: Math.min(root.maxRowWidth,
        Math.max(1, WindowState.windows.length) * (root.cardWidth + root.cardSpacing)
        - root.cardSpacing)

    screen: pickerScreen
    visible: WindowState.open && root.onFocusedScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-window-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property double shownAt: 0

    onVisibleChanged: {
        if (!root.visible)
            return;
        root.shownAt = Date.now();
        keys.forceActiveFocus();
    }

    // Подтверждение — только по реальному отпусканию Alt (QML key release
    // или compositor-бинд). Таймера нет: пока Alt зажат, панель не исчезает.

    function iconFor(appClass, title) {
        let entry = DesktopEntries.heuristicLookup(appClass);
        if (!entry && title)
            entry = DesktopEntries.heuristicLookup(title);
        const iconName = entry && entry.icon ? entry.icon : appClass;
        const found = Quickshell.iconPath(iconName, true);
        return found !== "" ? found : Quickshell.iconPath("application-x-executable", true);
    }

    function accept() {
        WindowState.activate();
    }

    Connections {
        target: WindowState

        function onOpenChanged() {
            if (WindowState.open)
                keys.forceActiveFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: WindowState.cancel()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: WindowState.cancel()
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: root.rowWidth + 28
        height: list.height + 54
        radius: Theme.notificationRadius
        color: Theme.withAlpha(Theme.quickBackground, 0.96)
        border.width: 1
        border.color: Theme.quickBorder

        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            ListView {
                id: list

                width: parent.width
                height: root.cardHeight
                orientation: ListView.Horizontal
                spacing: root.cardSpacing
                model: WindowState.windows
                currentIndex: WindowState.cursor
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    required property int index

                    width: root.cardWidth
                    height: root.cardHeight
                    radius: 10
                    color: tile.index === WindowState.cursor ? Theme.quickTileActive
                         : hover.hovered ? Theme.quickTileHover : "transparent"
                    border.width: tile.index === WindowState.cursor ? 2 : 1
                    border.color: tile.index === WindowState.cursor ? Theme.accent
                                  : Theme.withAlpha(Theme.quickText, 0.06)

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            WindowState.cursor = tile.index;
                            WindowState.activate();
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Item {
                            width: 52
                            height: 52
                            anchors.horizontalCenter: parent.horizontalCenter

                            Image {
                                anchors.fill: parent
                                source: root.iconFor(tile.modelData.appClass, tile.modelData.title)
                                sourceSize: Qt.size(52, 52)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        Text {
                            width: parent.width
                            height: 38
                            text: tile.modelData.title
                            color: Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: tile.modelData.appClass
                            color: Theme.quickTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: WindowState.windows.length === 0
                      ? "Нет открытых окон"
                      : "Tab — дальше · Shift+Tab — назад · отпустите Alt — перейти · Esc — отмена"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: WindowState.lastError !== ""
                text: WindowState.lastError
                color: Theme.lowColor
                font.family: Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab) {
                WindowState.cycle(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                WindowState.cycle(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                WindowState.cycle(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.accept();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                WindowState.cancel();
                event.accepted = true;
            }
        }

        // Отпускание Alt подтверждает выбор, как в Windows Alt+Tab.
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr) {
                WindowState.commit();
                event.accepted = true;
            }
        }
    }
}
