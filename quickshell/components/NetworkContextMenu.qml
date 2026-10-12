import QtQuick
import Quickshell
import Quickshell.Wayland
import "quick"
import "../singletons"

// Контекстное меню сохранённой Wi-Fi сети (правый клик по строке в списке):
// «сменить пароль» и «забыть сеть». Удаление спрашивает подтверждение прямо
// здесь: у сохранённой сети уходят и пароль, и настройки профиля — например,
// статический IP.
//
// Это не попап: попап привязывается к окну панели, а окно бара — тонкая
// полоска сверху, и позиционирование от него ненадёжно. Вместо этого —
// прозрачная поверхность на весь экран: координаты клика глобальные,
// карточка кладётся прямо по ним, клик мимо закрывает меню.
PanelWindow {
    id: root

    // Экран берём у окна панели, из которого открыли меню: если окна нет
    // (диагностический вызов), падаем на первый экран.
    readonly property ShellScreen menuScreen: {
        const window = UiState.menuWindow;
        if (window !== null && window.screen !== undefined && window.screen !== null)
            return window.screen;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    readonly property var network: NetworkService.findNetwork(UiState.menuNetwork)
    readonly property bool confirming: NetworkService.forgetPending !== ""
    // Высота карточки: пункты меню или подтверждение удаления.
    readonly property real cardHeight: (confirming ? confirmItem.implicitHeight
                                                   : column.implicitHeight) + 8
    // Не выпускаем карточку за нижний край экрана.
    readonly property real cardY: {
        const screenHeight = menuScreen ? menuScreen.height : 1800;
        return Math.max(4, Math.min(UiState.menuY, screenHeight - cardHeight - 8));
    }

    screen: menuScreen
    visible: UiState.menuNetwork !== "" && root.menuScreen !== null
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-network-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onVisibleChanged: if (!visible)
        NetworkService.cancelForget()

    // Клик мимо карточки закрывает меню.
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    function close() {
        UiState.closeNetworkMenu();
    }


    // Мягкая тень: меню висит поверх произвольного окна, и без неё карточка
    // сливается с тёмным фоном под ней.
    Rectangle {
        x: card.x + 2
        y: card.y + 6
        width: card.width
        height: card.height
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    Rectangle {
        id: card
        x: Math.max(4, Math.min(UiState.menuX,
                                (root.menuScreen ? root.menuScreen.width : 1000) - width - 8))
        y: root.cardY
        width: 236
        height: root.cardHeight
        radius: 14
        // Фон светлее обычной поверхности и полностью непрозрачный: меню
        // висит поверх произвольного приложения, и на его фоне карточка
        // должна читаться как отдельная плоскость, а не как «текст без фона».
        color: "transparent"
        border.width: 1
        border.color: Theme.menuBorder

        // Клики по карточке не должны её закрывать.
        MouseArea {
            anchors.fill: parent
        }

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
