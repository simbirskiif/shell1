import QtQuick
import ".."
import "../../singletons"

// Содержимое раскрытого дока: список приложений и настройки дока. Это
// «большая панель», в которую плавно превращается компактная полоса.
Item {
    id: root

    required property string screenName

    signal closeRequested()

    // Настройки открываются поверх сетки, а не отдельным окном: панель уже
    // держит и маску ввода, и фокус-граб для закрытия по клику мимо.
    // Состояние в DockState, чтобы панель переживала пересоздание и
    // переключалась по IPC.
    readonly property bool settingsOpen: DockState.settingsOpen

    // Шапка остаётся на месте, содержимое прокручивается.
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34

        Text {
            id: titleText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.settingsOpen ? "Настройки дока" : "Приложения"
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: titleText.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.settingsOpen && DockApps.all.length > 0
            text: "· " + DockApps.all.length
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: header.verticalCenter
        spacing: 2

        DockIconButton {
            size: 34
            glyphSize: 14
            icon: "\uf013"
            accented: root.settingsOpen

            onClicked: DockState.settingsOpen = !DockState.settingsOpen
        }

        DockIconButton {
            size: 34
            glyphSize: 14
            icon: "\uf00d"

            onClicked: root.closeRequested()
        }
    }

    // --- сетка приложений -------------------------------------------------
    GridView {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: width / Theme.dockGridColumns
        cellHeight: Theme.dockGridCellHeight
        model: DockApps.all
        enabled: !root.settingsOpen
        opacity: root.settingsOpen ? 0 : 1
        visible: opacity > 0.001
        // Быстрый fade-through, как у смены видов в остальных панелях.
        Behavior on opacity {
            MotionNumber {
                duration: Theme.dockFadeDuration
                curve: Theme.curveEmphasized
            }
        }

        delegate: DockGridApp {
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight
            entry: modelData
            iconSize: Math.max(32, Math.min(56, Math.round(DockSettings.iconSize * 1.6)))
            onActivated: DockState.hide()
        }
    }

    // Свой обработчик колеса: у GridView нет настройки чувствительности.
    // Слой прозрачен для кликов и касаний — они уходят кнопкам под ним;
    // перехватывается только вертикальное колесо.
    Item {
        anchors.fill: grid
        visible: !root.settingsOpen

        WheelHandler {
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
            orientation: Qt.Vertical

            onWheel: (event) => {
                const dy = event.pixelDelta.y !== 0
                    ? event.pixelDelta.y
                    : event.angleDelta.y * 0.5;
                if (dy === 0)
                    return;
                const maxY = Math.max(0, grid.contentHeight - grid.height);
                grid.contentY = Math.max(0, Math.min(maxY,
                    grid.contentY - dy * DockSettings.scrollFactor));
                event.accepted = true;
            }
        }
    }

    // --- настройки дока ---------------------------------------------------
    DockPanelSettings {
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        enabled: root.settingsOpen
        opacity: root.settingsOpen ? 1 : 0
        visible: opacity > 0.001
        Behavior on opacity {
            MotionNumber {
                duration: Theme.dockFadeDuration
                curve: Theme.curveEmphasized
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: DockApps.all.length === 0 && !root.settingsOpen
        text: "Список приложений пуст"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
