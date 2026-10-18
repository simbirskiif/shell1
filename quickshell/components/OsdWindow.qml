import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../singletons"

// Нижний индикатор громкости и яркости: выезжает снизу, живёт в оверлее,
// не забирает ни клавиатуру, ни фокус и не мешает кликам.
// Показывается на том экране, где сейчас фокус (если Hyprland молчит —
// на первом).
PanelWindow {
    id: root

    // Экран задаёт делегат Variants (screen: modelData). Своей копии
    // required property modelData здесь быть не должно: она конфликтует
    // с делегатом, и вариант не создаётся.

    anchors.bottom: true
    margins.bottom: 84
    // Высота с запасом под выезд: карточка приходит снизу на 30 px.
    implicitWidth: 360
    implicitHeight: 132
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.focusable: false

    readonly property string focusedMonitorName: {
        const monitor = Hyprland.focusedMonitor;
        return (monitor === null || monitor === undefined) ? "" : monitor.name;
    }

    readonly property bool onFocusedScreen: root.focusedMonitorName !== ""
        ? (root.screen !== null && root.screen.name === root.focusedMonitorName)
        : (Quickshell.screens.length > 0 && root.screen === Quickshell.screens[0])

    // Окно снимаем с экрана только после анимации ухода.
    property bool keepingAlive: false
    visible: (Osd.shown || root.keepingAlive) && root.onFocusedScreen

    // Значение, которое догоняет Osd.value: и полоска, и процент едут
    // анимацией, а не прыгают.
    property real displayValue: 0
    Behavior on displayValue {
        MotionNumber {
            duration: Theme.motionMedium1
            curve: Theme.curveStandard
        }
    }

    Connections {
        target: Osd

        function onShownChanged() {
            if (Osd.shown) {
                root.keepingAlive = true;
                exitTimer.stop();
            } else {
                exitTimer.restart();
            }
        }

        function onValueChanged() {
            root.displayValue = Osd.muted ? 0 : Osd.value;
        }

        function onMutedChanged() {
            root.displayValue = Osd.muted ? 0 : Osd.value;
        }
    }

    Component.onCompleted: {
        root.displayValue = Osd.muted ? 0 : Osd.value;
        if (Osd.shown)
            root.keepingAlive = true;
    }

    Timer {
        id: exitTimer
        interval: 260
        onTriggered: root.keepingAlive = false
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: 340
        height: 92
        radius: 18
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder

        opacity: Osd.shown ? 1 : 0
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveStandard
            }
        }

        transform: Translate {
            y: Osd.shown ? 0 : 30
            Behavior on y {
                MotionNumber {
                    duration: Theme.motionMedium1
                    curve: Theme.curveEmphasized
                }
            }
        }

        Text {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 16
            text: Osd.muted ? "\uf026"
                : Osd.kind === "input" ? "\uf130"
                : Osd.kind === "brightness" ? "\uf185"
                : "\uf028"
            color: Osd.muted ? Theme.quickTextDim : Theme.quickText
            font.family: Theme.iconFontFamily
            font.pixelSize: 16
        }

        Text {
            id: title
            anchors.left: icon.right
            anchors.leftMargin: 12
            anchors.right: percent.left
            anchors.rightMargin: 12
            anchors.verticalCenter: icon.verticalCenter
            text: Osd.title
            elide: Text.ElideRight
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            id: percent
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: icon.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: Osd.muted ? "Выкл." : Math.round(root.displayValue * 100) + "%"
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            height: 8
            radius: height / 2
            color: Theme.quickCircleOff

            Rectangle {
                id: fill
                width: Math.max(track.height, track.width * root.displayValue)
                height: track.height
                radius: track.radius
                color: Theme.accent
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: fill.width - width / 2
                width: 16
                height: 16
                radius: width / 2
                color: "#ffffff"
            }
        }
    }
}
