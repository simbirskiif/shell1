import QtQuick
import Quickshell
import ".."
import "../expressive"
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
//
// Expressive: плавающая карточка с радиусом 32, пункты — крупные пилюли,
// hover — secondary-контейнер (у удаления — error-контейнер). Разделителей
// нет, группы читаются формой и цветом.
Item {
    id: root

    // Клик мимо карточки закрывает меню.
    anchors.fill: parent

    readonly property var network: NetworkService.findNetwork(UiState.menuNetwork)
    readonly property bool confirming: NetworkService.forgetPending !== ""
    readonly property bool open: UiState.menuNetwork !== ""

    // Меню Expressive: плавающая карточка с крупными пунктами-пилюлями.
    readonly property real cardHeight: column.implicitHeight + Theme.space.lg
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

    // Плавающая карточка меню: радиус 32, тональная поверхность, без рамки.
    Rectangle {
        id: card
        x: Math.max(Theme.space.sm, Math.min(UiState.menuX, root.width - width - Theme.space.sm))
        y: Math.max(Theme.space.sm, Math.min(UiState.menuY, root.height - height - Theme.space.sm))
        width: 250
        height: root.cardHeight
        radius: Theme.shape.xlIncreased
        color: Theme.menuSurfaceSolid

        // Клики по карточке не должны её закрывать.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.space.sm
            spacing: 2

            // Пункт «сменить пароль»: пилюля, hover — secondary-контейнер.
            Item {
                id: changeRow
                width: parent.width
                visible: !root.confirming
                height: visible ? 52 : 0

                readonly property bool hovered: changeHover.containsMouse
                readonly property bool pressed: changeHover.pressed

                scale: pressed ? 0.98 : 1
                Behavior on scale { SpringSpatialFast {} }

                MorphShape {
                    anchors.fill: parent
                    shape: changeRow.hovered ? "squircle" : "pill"
                    color: changeRow.hovered ? Theme.secondaryContainer : "transparent"
                    modulation: 0.35

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: changeIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf084"
                    color: changeRow.hovered ? Theme.scheme.onSecondaryContainer
                                             : Theme.scheme.onSurfaceVariant
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    anchors.left: changeIcon.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: "Change password"
                    color: changeRow.hovered ? Theme.scheme.onSecondaryContainer
                                             : Theme.scheme.onSurface
                    font: Theme.typeEmphasizedLabelLarge
                }

                MouseArea {
                    id: changeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NetworkService.changePassword(UiState.menuNetwork);
                        root.close();
                    }
                }
            }

            // Пункт «забыть сеть»: опасное действие — error-цвет и на hover
            // error-контейнер, но та же крупная пилюля.
            Item {
                id: forgetRow
                width: parent.width
                visible: !root.confirming
                height: visible ? 52 : 0

                readonly property bool hovered: forgetHover.containsMouse
                readonly property bool pressed: forgetHover.pressed

                scale: pressed ? 0.98 : 1
                Behavior on scale { SpringSpatialFast {} }

                MorphShape {
                    anchors.fill: parent
                    shape: forgetRow.hovered ? "squircle" : "pill"
                    color: forgetRow.hovered ? Theme.errorContainer : "transparent"
                    modulation: 0.35

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: forgetIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf1f8"
                    color: Theme.error
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    anchors.left: forgetIcon.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: "Forget network"
                    color: Theme.error
                    font: Theme.typeEmphasizedLabelLarge
                }

                MouseArea {
                    id: forgetHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkService.beginForget(UiState.menuNetwork)
                }
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
                        leftPadding: Theme.space.sm
                        rightPadding: Theme.space.sm
                        topPadding: Theme.space.sm
                        wrapMode: Text.WordWrap
                        text: "Forget " + UiState.menuNetwork + "?"
                        color: Theme.scheme.onSurface
                        font: Theme.typeEmphasizedTitleMedium
                    }

                    Text {
                        width: parent.width
                        leftPadding: Theme.space.sm
                        rightPadding: Theme.space.sm
                        wrapMode: Text.WordWrap
                        text: "Saved password and profile settings will be removed"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.xs
                        bottomPadding: Theme.space.xs
                        spacing: Theme.space.sm

                        // «Отмена» — тональная пилюля.
                        Item {
                            id: cancelButton
                            width: cancelLabel.implicitWidth + Theme.space.xl
                            height: 44
                            scale: cancelHover.pressed ? 0.94 : (cancelHover.containsMouse ? 1.04 : 1)

                            Behavior on scale { SpringSpatialFast {} }

                            MorphShape {
                                anchors.fill: parent
                                shape: cancelHover.containsMouse ? "squircle" : "pill"
                                color: Theme.surfaceContainerHigh
                                modulation: 0.4
                            }

                            Text {
                                id: cancelLabel
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: Theme.scheme.onSurface
                                font: Theme.typeEmphasizedLabelLarge
                            }

                            MouseArea {
                                id: cancelHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkService.cancelForget()
                            }
                        }

                        // «Забыть» — залитая error-пилюля.
                        Item {
                            id: forgetButton
                            readonly property bool hovered: forgetHover2.containsMouse
                            width: forgetLabel.implicitWidth + Theme.space.xl
                            height: 44
                            scale: forgetHover2.pressed ? 0.94 : (hovered ? 1.04 : 1)

                            Behavior on scale { SpringSpatialFast {} }

                            MorphShape {
                                anchors.fill: parent
                                shape: forgetButton.hovered ? "squircle" : "pill"
                                color: Theme.error
                                modulation: 0.4
                            }

                            Text {
                                id: forgetLabel
                                anchors.centerIn: parent
                                text: "Forget"
                                color: Theme.scheme.onError
                                font: Theme.typeEmphasizedLabelLarge
                            }

                            MouseArea {
                                id: forgetHover2
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    NetworkService.confirmForget();
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
