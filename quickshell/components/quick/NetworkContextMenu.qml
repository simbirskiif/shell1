import QtQuick
import Quickshell
import ".."
import "../../singletons"

// Контекстное меню сохранённой Wi-Fi сети (правый клик по строке в списке):
// «сменить пароль» и «забыть сеть». Удаление спрашивает подтверждение прямо
// здесь: у сохранённой сети уходят и пароль, и настройки профиля — например,
// статический IP.
//
// Меню живёт внутри того же окна, что и панель быстрых настроек: это
// PopupWindow, и он рисуется поверх любых layer-shell поверхностей. Отдельная
// поверхность оказывалась под панелью и была не видна. Поэтому координаты
// клика — локальные для окна панели, а карточка кладётся прямо по ним.
Item {
    id: root

    // Клик мимо карточки закрывает меню.
    anchors.fill: parent

    readonly property var network: NetworkService.findNetwork(UiState.menuNetwork)
    readonly property bool confirming: NetworkService.forgetPending !== ""
    readonly property bool open: UiState.menuNetwork !== ""

    // Высота карточки. Считаем по колонке целиком: она сама учитывает
    // состояние — скрытые пункты имеют height 0, а блок подтверждения свою
    // высоту. Прежний вариант брал при подтверждении только confirmItem и
    // ЗАБЫВАЛ заголовок с именем и зарядом, который остаётся видимым: карточка
    // выходила на ~50 px ниже, и кнопки «Отмена»/«Удалить» оказывались за её
    // пределами.
    readonly property real cardHeight: column.implicitHeight + 8
    // То же, что в меню Bluetooth: окно берёт высоту карточки целиком.
    readonly property real maxCardHeight: cardHeight

    visible: open

    onVisibleChanged: if (!visible)
        NetworkService.cancelForget()

    function close() {
        UiState.closeNetworkMenu();
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.close()
    }

    Rectangle {
        id: card
        x: Math.max(4, Math.min(UiState.menuX, root.width - width - 8))
        y: Math.max(4, Math.min(UiState.menuY, root.height - height - 8))
        width: 236
        height: root.cardHeight
        radius: 14
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder

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
