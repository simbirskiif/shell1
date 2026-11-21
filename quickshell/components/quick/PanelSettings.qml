import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Настройки оболочки: процент батареи в баре и порядок элементов бара.
//
// Expressive: настройки сгруппированы формой — каждая строка это крупный
// squircle-контейнер на тональной поверхности, заголовки секций —
// typeEmphasizedTitleMedium. Тонких разделителей нет: группы разделяет
// воздух, кнопки-стрелки — круги на пружинах.
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

        // --- Bar ---------------------------------------------------------
        Item {
            width: parent.width
            height: 44

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xs
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space.xs
                text: "Bar"
                color: Theme.primary
                font: Theme.typeEmphasizedTitleMedium
            }
        }

        // Двухстрочная строка списка m3: заголовок и подпись.
        Item {
            width: parent.width
            height: 64

            readonly property bool hovered: batteryRowHover.containsMouse

            MorphShape {
                anchors.fill: parent
                anchors.topMargin: Theme.space.xs / 2
                anchors.bottomMargin: Theme.space.xs / 2
                shape: "squircle"
                color: Theme.surfaceContainerHigh
                modulation: 0.35
            }

            MouseArea {
                id: batteryRowHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.right: toggle.left
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: "Battery percentage"
                    color: Theme.scheme.onSurface
                    font: Theme.typeEmphasizedLabelLarge
                }

                Text {
                    text: "Show charge level next to the icon"
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodySmall
                }
            }

            ToggleSwitch {
                id: toggle
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                checked: MockState.showBatteryPercent
                onToggled: MockState.showBatteryPercent = !MockState.showBatteryPercent
            }
        }

        // --- Notifications ----------------------------------------------
        Item {
            width: parent.width
            height: 48

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xs
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space.xs
                text: "Notifications"
                color: Theme.primary
                font: Theme.typeEmphasizedTitleMedium
            }
        }

        // Чувствительность горизонтального свайпа: множитель дельты
        // тачпада. 1.00 — карточка идёт ровно за пальцами.
        Item {
            width: parent.width
            height: 92

            MorphShape {
                anchors.fill: parent
                anchors.topMargin: Theme.space.xs / 2
                anchors.bottomMargin: Theme.space.xs / 2
                shape: "squircle"
                color: Theme.surfaceContainerHigh
                modulation: 0.35
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.top: parent.top
                anchors.topMargin: Theme.space.sm
                text: "Swipe sensitivity"
                color: Theme.scheme.onSurface
                font: Theme.typeEmphasizedLabelLarge
            }

            // Значение — крупная пилюля tertiary-контейнера.
            MorphShape {
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.md
                anchors.top: parent.top
                anchors.topMargin: Theme.space.sm - 2
                width: 64
                height: 30
                shape: "pill"
                color: Theme.tertiaryContainer
                modulation: 0.4

                Text {
                    anchors.centerIn: parent
                    text: NotificationService.swipeSensitivity.toFixed(2) + "×"
                    color: Theme.scheme.onTertiaryContainer
                    font: Theme.typeEmphasizedLabelLarge
                }
            }

            PanelSlider {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.md
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space.sm
                height: 24
                accent: Theme.primary
                // Ползунок 0..1 — это 0.5..3.0, шаг 0.05.
                value: (NotificationService.swipeSensitivity - 0.5) / 2.5
                onMoved: v => NotificationService.swipeSensitivity =
                             Math.round((0.5 + v * 2.5) * 20) / 20
            }
        }

        // --- Кофеин ------------------------------------------------------
        Item {
            width: parent.width
            height: 48

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xs
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space.xs
                text: "Кофеин"
                color: Theme.primary
                font: Theme.typeEmphasizedTitleMedium
            }
        }

        // Длительности кофеина строкой: "30, 1h, 2h 30m", без единицы —
        // минуты. Правит отдельное окно: попап клавиатуру не получает.
        Item {
            width: parent.width
            height: 64

            readonly property bool hovered: durationsHover.containsMouse
            readonly property bool pressed: durationsHover.pressed

            scale: pressed ? 0.99 : 1
            Behavior on scale { SpringSpatialFast {} }

            MorphShape {
                anchors.fill: parent
                anchors.topMargin: Theme.space.xs / 2
                anchors.bottomMargin: Theme.space.xs / 2
                shape: "squircle"
                color: parent.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                modulation: 0.35

                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.right: editIcon.left
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: "Длительности"
                    color: Theme.scheme.onSurface
                    font: Theme.typeEmphasizedLabelLarge
                }

                Text {
                    width: parent.width
                    text: CaffeineService.durations !== "" ? CaffeineService.durations : "не заданы"
                    elide: Text.ElideRight
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodySmall
                }
            }

            // Кнопка-иконка 44: круг, на hover — «печенье» primary-контейнера.
            MorphShape {
                id: editIcon
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                shape: durationsHover.containsMouse ? "cookie" : "circle"
                color: durationsHover.containsMouse ? Theme.primaryContainer
                                                   : Theme.surfaceContainerHighest
                modulation: 1

                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf040"
                    color: durationsHover.containsMouse ? Theme.scheme.onPrimaryContainer
                                                        : Theme.scheme.onSurfaceVariant
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }
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

        // --- Bar order ---------------------------------------------------
        Item {
            width: parent.width
            height: 48

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xs
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space.xs
                text: "Bar order"
                color: Theme.primary
                font: Theme.typeEmphasizedTitleMedium
            }
        }

        // Порядок слева-направо = порядок в модели; стрелки двигают элемент.
        PanelList {
            width: parent.width
            rowHeight: 56
            model: MockState.barItems

            delegate: Item {
                id: orderRow

                required property string itemKey
                required property string title
                required property int index

                readonly property bool hovered: rowHover.containsMouse

                width: ListView.view ? ListView.view.width : implicitWidth
                height: 56

                MorphShape {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    shape: "squircle"
                    color: orderRow.hovered ? Theme.surfaceContainerHigh : "transparent"
                    modulation: 0.3

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: orderRow.title
                    color: Theme.scheme.onSurface
                    font: Theme.typeEmphasizedLabelLarge
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xs

                    // Кнопки-иконки m3: 44×44, круг, hover — primary-контейнер.
                    MorphShape {
                        id: upButton

                        readonly property bool available: orderRow.index > 0

                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        shape: upHover.containsMouse && available ? "cookie" : "circle"
                        color: upHover.containsMouse && available ? Theme.primaryContainer
                                                                  : Theme.surfaceContainerHighest
                        modulation: 1
                        opacity: available ? 1 : Theme.disabledContent
                        scale: upHover.pressed && available ? 0.9 : 1

                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on opacity { SpringEffects {} }
                        Behavior on scale { SpringSpatialFast {} }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf077"
                            color: upHover.containsMouse && upButton.available
                                   ? Theme.scheme.onPrimaryContainer
                                   : Theme.scheme.onSurface
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

                    MorphShape {
                        id: downButton

                        readonly property bool available: orderRow.index < MockState.barItems.count - 1

                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        shape: downHover.containsMouse && available ? "cookie" : "circle"
                        color: downHover.containsMouse && available ? Theme.primaryContainer
                                                                    : Theme.surfaceContainerHighest
                        modulation: 1
                        opacity: available ? 1 : Theme.disabledContent
                        scale: downHover.pressed && available ? 0.9 : 1

                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on opacity { SpringEffects {} }
                        Behavior on scale { SpringSpatialFast {} }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf078"
                            color: downHover.containsMouse && downButton.available
                                   ? Theme.scheme.onPrimaryContainer
                                   : Theme.scheme.onSurface
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
