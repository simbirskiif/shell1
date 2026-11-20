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
    readonly property real cardHeight: column.implicitHeight + Theme.space.sm
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

    // Карточка меню m3: тональная поверхность surface-container-high,
    // радиус medium, без тени — глубину даёт только тон.
    Rectangle {
        id: card
        x: Math.max(Theme.space.xs, Math.min(UiState.menuX, root.width - width - Theme.space.sm))
        y: Math.max(Theme.space.xs, Math.min(UiState.menuY, root.height - height - Theme.space.sm))
        width: 236
        height: root.cardHeight
        radius: Theme.shape.md
        color: Theme.menuSurfaceSolid
        border.width: 1
        border.color: Theme.outlineVariant

        // Клики по карточке не должны её закрывать.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.space.xs
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
                    spacing: Theme.space.xs

                    Text {
                        width: parent.width
                        leftPadding: Theme.space.md
                        rightPadding: Theme.space.md
                        topPadding: Theme.space.sm
                        wrapMode: Text.WordWrap
                        text: "Forget " + UiState.menuNetwork + "?"
                        color: Theme.scheme.onSurface
                        font: Theme.typeBodyLarge
                    }

                    Text {
                        width: parent.width
                        leftPadding: Theme.space.md
                        rightPadding: Theme.space.md
                        wrapMode: Text.WordWrap
                        text: "Saved password and profile settings will be removed"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.sm
                        bottomPadding: Theme.space.xs
                        spacing: Theme.space.sm

                        MenuButton {
                            text: "Cancel"
                            onTriggered: NetworkService.cancelForget()
                        }

                        MenuButton {
                            text: "Forget"
                            primary: true
                            danger: true
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

    // Пункт меню m3: иконка, подпись, подсветка опасного действия.
    // Высота пункта — 48, hover — state layer поверх скруглённой подложки.
    component MenuRow: Item {
        id: row

        property string icon: ""
        property string text: ""
        property bool danger: false

        signal triggered()

        implicitWidth: column.width
        implicitHeight: Theme.touchTarget

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.space.xs
            radius: Theme.shape.xs
            color: rowHover.containsMouse
                   ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                   : "transparent"
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
            anchors.leftMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            text: row.icon
            color: row.danger ? Theme.error : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
        }

        Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: Theme.space.md
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.text
            color: row.danger ? Theme.error : Theme.scheme.onSurface
            font: Theme.typeLabelLarge
        }
    }

    // Кнопка m3: текстовая (прозрачная, подпись primary) или залитая (primary).
    component MenuButton: Rectangle {
        id: button

        property string text: ""
        property bool primary: false
        property bool danger: false

        signal triggered()

        readonly property color accentColor: button.danger ? Theme.error : Theme.primary
        readonly property color accentLabel: button.danger ? Theme.scheme.onError
                                                           : Theme.scheme.onPrimary

        width: buttonLabel.implicitWidth + Theme.space.xl
        height: Theme.buttonHeight
        radius: Theme.shape.full
        color: button.primary ? button.accentColor : "transparent"

        // Слой состояния m3: на залитой кнопке — по on-primary, на текстовой —
        // по primary.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: button.primary
                   ? Theme.stateLayer(button.accentLabel, Theme.stateHover)
                   : Theme.stateLayer(button.accentColor, Theme.stateHover)
            opacity: buttonHover.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? button.accentLabel : button.accentColor
            font: Theme.typeLabelLarge
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
