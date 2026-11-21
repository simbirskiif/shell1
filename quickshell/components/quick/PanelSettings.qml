import QtQuick
import ".."
import "../../singletons"

// Настройки оболочки: процент батареи в баре и порядок элементов бара.
Item {
    id: root

    signal backRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: "Settings"
            checked: false
            switchable: false
            onBackRequested: root.backRequested()
        }

        // Разделитель шапки m3 — outline-variant.
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PanelSection { text: "Bar" }

        // Двухстрочная строка списка m3: заголовок и подпись.
        Item {
            width: parent.width
            height: Theme.listItemHeight + Theme.space.sm

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.lg
                anchors.right: toggle.left
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.xs

                Text {
                    text: "Battery percentage"
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                }

                Text {
                    text: "Show charge level next to the icon"
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }
            }

            ToggleSwitch {
                id: toggle
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                checked: MockState.showBatteryPercent
                onToggled: MockState.showBatteryPercent = !MockState.showBatteryPercent
            }
        }

        PanelSection { text: "Notifications" }

        // Чувствительность горизонтального свайпа: множитель дельты
        // тачпада. 1.00 — карточка идёт ровно за пальцами.
        Item {
            width: parent.width
            height: Theme.listItemHeight + Theme.space.lg

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.lg
                anchors.right: sensitivityValue.left
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.sm

                Text {
                    text: "Swipe sensitivity"
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                }

                PanelSlider {
                    width: parent.width
                    // Ползунок 0..1 — это 0.5..3.0, шаг 0.05.
                    value: (NotificationService.swipeSensitivity - 0.5) / 2.5
                    onMoved: v => NotificationService.swipeSensitivity =
                                 Math.round((0.5 + v * 2.5) * 20) / 20
                }
            }

            Text {
                id: sensitivityValue

                anchors.right: parent.right
                anchors.rightMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                text: NotificationService.swipeSensitivity.toFixed(2) + "×"
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodyMedium
            }
        }

        PanelSection { text: "Кофеин" }

        // Длительности кофеина строкой: "30, 1h, 2h 30m", без единицы —
        // минуты. Правит отдельное окно: попап клавиатуру не получает.
        Item {
            width: parent.width
            height: Theme.listItemHeight + Theme.space.sm

            // Строка списка m3: hover — state layer on-surface.
            Rectangle {
                anchors.fill: parent
                color: durationsHover.containsMouse
                       ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.lg
                anchors.right: editIcon.left
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.xs

                Text {
                    text: "Длительности"
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                }

                Text {
                    width: parent.width
                    text: CaffeineService.durations !== "" ? CaffeineService.durations : "не заданы"
                    elide: Text.ElideRight
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }
            }

            Text {
                id: editIcon
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf040"
                color: Theme.scheme.onSurfaceVariant
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.md
            }

            MouseArea {
                id: durationsHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: UiState.requestInput("caffeine.durations", "Длительности кофеина",
                                                "Например: 30, 1h, 2h 30m. Число без единицы — минуты.",
                                                CaffeineService.durations)
            }
        }

        PanelSection { text: "Bar order" }

        // Порядок слева-направо = порядок в модели; стрелки двигают элемент.
        PanelList {
            width: parent.width
            rowHeight: Theme.touchTarget
            model: MockState.barItems

            delegate: Item {
                id: orderRow

                required property string itemKey
                required property string title
                required property int index

                width: ListView.view ? ListView.view.width : implicitWidth
                height: Theme.touchTarget

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    text: orderRow.title
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xs

                    // Кнопки-иконки m3: 40×40, круглые, hover — state layer.
                    Rectangle {
                        id: upButton

                        readonly property bool available: orderRow.index > 0

                        width: Theme.iconButtonSize
                        height: Theme.iconButtonSize
                        radius: Theme.shape.full
                        color: upHover.containsMouse && available
                               ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                               : "transparent"
                        opacity: available ? 1 : Theme.disabledContent
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf077"
                            color: Theme.scheme.onSurface
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.md
                        }

                        MouseArea {
                            id: upHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: upButton.available
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MockState.moveBarItem(orderRow.index, -1)
                        }
                    }

                    Rectangle {
                        id: downButton

                        readonly property bool available: orderRow.index < MockState.barItems.count - 1

                        width: Theme.iconButtonSize
                        height: Theme.iconButtonSize
                        radius: Theme.shape.full
                        color: downHover.containsMouse && available
                               ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                               : "transparent"
                        opacity: available ? 1 : Theme.disabledContent
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf078"
                            color: Theme.scheme.onSurface
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.md
                        }

                        MouseArea {
                            id: downHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: downButton.available
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MockState.moveBarItem(orderRow.index, 1)
                        }
                    }
                }
            }
        }
    }
}
