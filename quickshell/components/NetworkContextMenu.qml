import QtQuick
import Quickshell
import "quick"
import "../singletons"

// Контекстное меню сохранённой Wi-Fi сети (правый клик по строке в списке):
// сменить пароль и забыть сеть. Удаление спрашивает подтверждение прямо
// здесь: у сохранённой сети уходят и пароль, и настройки профиля — например,
// статический IP.
PopupWindow {
    id: root

    readonly property var network: NetworkService.findNetwork(UiState.menuNetwork)
    readonly property bool confirming: NetworkService.forgetPending !== ""

    color: "transparent"
    visible: UiState.menuNetwork !== ""
    implicitWidth: 236
    implicitHeight: cardHeight
    // Меню закрывается по клику мимо, фокус клавиатуры ему не нужен.
    grabFocus: false

    // Точка клика в глобальных координатах экрана: меню растёт из курсора
    // вниз-вправо. Привязка к экрану, а не к окну бара: окно бара — тонкая
    // полоска сверху, и попап от него позиционируется ненадёжно.
    screen: root.parentScreen
    anchor.rect.x: UiState.menuX
    anchor.rect.y: UiState.menuY
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    // Экран, на котором открыто меню: тот же, что у быстрой панели.
    readonly property ShellScreen parentScreen: {
        const screen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        return screen;
    }

    readonly property real cardHeight: (confirming ? confirmItem.implicitHeight
                                                   : column.implicitHeight) + 8

    Connections {
        target: UiState

        // Быстрая панель закрылась — меню тоже не нужно.
        function onOpenedScreenChanged() {
            if (UiState.openedScreen === "")
                UiState.closeNetworkMenu();
        }
    }

    onVisibleChanged: if (!visible)
        NetworkService.cancelForget()

    function close() {
        UiState.closeNetworkMenu();
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        radius: 14
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 0

            MenuRow {
                visible: !root.confirming
                height: root.confirming ? 0 : implicitHeight
                icon: "\uf084"
                text: "Change password"
                onTriggered: {
                    NetworkService.changePassword(UiState.menuNetwork);
                    root.close();
                }
            }

            MenuRow {
                visible: !root.confirming
                height: root.confirming ? 0 : implicitHeight
                icon: "\uf1f8"
                text: "Forget network"
                danger: true
                onTriggered: NetworkService.beginForget(UiState.menuNetwork)
            }

            // Подтверждение удаления.
            Item {
                id: confirmItem
                width: parent.width
                visible: root.confirming
                implicitHeight: confirmColumn.implicitHeight

                Column {
                    id: confirmColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 4

                    Text {
                        width: parent.width
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 8
                        wrapMode: Text.WordWrap
                        text: "Forget " + UiState.menuNetwork + "?"
                        color: Theme.quickText
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        leftPadding: 12
                        rightPadding: 12
                        wrapMode: Text.WordWrap
                        text: "Saved password and profile settings will be removed"
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        bottomPadding: 2
                        spacing: 6

                        MenuButton {
                            text: "Cancel"
                            onTriggered: NetworkService.cancelForget()
                        }

                        MenuButton {
                            text: "Forget"
                            primary: true
                            onTriggered: {
                                NetworkService.confirmForget();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Item {
        id: row

        property string icon: ""
        property string text: ""
        property bool danger: false

        signal triggered()

        implicitWidth: column.width
        implicitHeight: 40

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 10
            color: rowHover.hovered ? Theme.quickTileHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.triggered()
        }

        Text {
            id: rowIcon
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: row.icon
            color: row.danger ? Theme.lowColor : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 13
        }

        Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.text
            color: row.danger ? Theme.lowColor : Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    component MenuButton: Rectangle {
        id: button

        property string text: ""
        property bool primary: false

        signal triggered()

        width: buttonLabel.implicitWidth + 28
        height: 32
        radius: height / 2
        color: button.primary ? Theme.accent
                              : (buttonHover.hovered ? Theme.quickTileHover : Theme.quickTile)

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? Theme.quickIconOn : Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: buttonHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
