import QtQuick
import ".."
import "../../singletons"

// Панель питания: заряд батареи, состояние и время, выбор режима питания.
// Данные и действия — в PowerService (UPower и power-profiles-daemon).
// Если демон режимов недоступен, вместо сегментов показывается плашка.
Item {
    id: root

    signal backRequested()

    // Подробности прячем целиком, если данных нет (нет батареи): пустой
    // заголовок секции выглядел бы недоделкой.
    readonly property bool hasDetails: PowerService.sourceText !== ""
        || PowerService.energyText !== ""
        || PowerService.powerText !== ""
        || PowerService.healthText !== ""
        || PowerService.model !== ""

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: I18n.tr("quick.tile.battery")
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

        // Заряд: «батарейка» с уровнем, процент, состояние и время.
        Item {
            width: parent.width
            height: 150

            // Большая батарейка — тот же дизайн, что и в баре.
            BatteryIndicator {
                id: batteryArt
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.space.xl
                level: PowerService.level
                charging: PowerService.charging
                bodyWidth: 150
                bodyHeight: 58
                bodyRadius: 18
                nubWidth: 7
            }

            Text {
                id: percentText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: batteryArt.bottom
                anchors.topMargin: Theme.space.md
                text: PowerService.present ? PowerService.level + "%" : "—"
                color: PowerService.present ? Theme.scheme.onSurface
                                            : Theme.scheme.onSurfaceVariant
                font: Theme.typeHeadlineSmall
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: percentText.bottom
                anchors.topMargin: Theme.space.xs
                text: {
                    if (!PowerService.present)
                        return I18n.tr("power.state.none");
                    if (PowerService.timeText === "")
                        return PowerService.stateText;
                    return PowerService.stateText + " · " + PowerService.timeText;
                }
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodyMedium
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PanelSection { text: I18n.tr("quick.battery.powerMode") }

        // power-profiles-daemon не отвечает: выбор режима невозможен, вместо
        // него — плашка с причиной и кнопкой повторной проверки.
        PanelWarning {
            width: parent.width
            // Высоту считаем от своего условия, а не от visible: visible
            // гаснет и вместе со скрытым предком, и тогда высота панели
            // схлопывалась прямо посреди жеста.
            readonly property bool shown: !PowerService.profilesAvailable
            visible: shown
            height: shown ? implicitHeight : 0
            title: I18n.tr("quick.battery.profilesUnavailable")
            description: I18n.tr("quick.battery.profilesDaemon")
            actionText: I18n.tr("common.retry")
            onActionRequested: PowerService.probeProfiles()
        }

        // Режим питания: три сегмента m3 segmented button — выбранный залит
        // secondary-container, Performance без поддержки железом неактивен.
        Item {
            width: parent.width
            height: PowerService.profilesAvailable ? Theme.listItemHeight : 0
            visible: height > 0

            readonly property real segmentWidth: (width - Theme.space.lg * 2
                                                 - Theme.space.sm * 2) / 3

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.sm

                Repeater {
                    model: PowerService.profiles

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool available: PowerService.isProfileAvailable(modelData.value)
                        readonly property bool selected: PowerService.profile === modelData.value

                        width: parent.parent.segmentWidth
                        height: Theme.buttonHeight
                        radius: Theme.shape.full
                        color: selected ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                        opacity: available ? 1 : Theme.disabledContent
                        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: selected ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface
                            font: Theme.typeLabelLarge
                            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.available
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: PowerService.setProfile(modelData.value)
                        }
                    }
                }
            }
        }

        // Демон сам сообщает, почему режим ограничен, и кто его держит.
        // Обёртка нужна из-за переноса строки: у самого Text связка
        // «height: visible ? implicitHeight : 0» даёт Binding loop.
        Item {
            width: parent.width
            readonly property bool shown: PowerService.profilesAvailable && noteText.text !== ""
            visible: shown
            height: shown ? noteText.implicitHeight : 0

            Text {
                id: noteText
                width: parent.width
                leftPadding: Theme.space.lg
                rightPadding: Theme.space.lg
                topPadding: Theme.space.sm
                bottomPadding: Theme.space.sm
                wrapMode: Text.WordWrap
                text: {
                    const parts = [];
                    if (PowerService.degradationText !== "")
                        parts.push(PowerService.degradationText);
                    if (PowerService.holdsText !== "")
                        parts.push(PowerService.holdsText);
                    return parts.join(" · ");
                }
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        // Подробности прячем целиком, если данных нет (нет батареи): пустой
        // заголовок секции выглядел бы недоделкой.
        Column {
            width: parent.width
            readonly property bool shown: root.hasDetails
            visible: shown
            height: shown ? implicitHeight : 0
            spacing: 0

            PanelSection { text: I18n.tr("common.details") }

            // Строки с пустым значением скрываются сами.
            PanelInfoRow { label: I18n.tr("quick.battery.source"); value: PowerService.sourceText }
            PanelInfoRow { label: I18n.tr("quick.battery.energy"); value: PowerService.energyText }
            PanelInfoRow { label: I18n.tr("quick.battery.power"); value: PowerService.powerText }
            PanelInfoRow { label: I18n.tr("quick.battery.health"); value: PowerService.healthText }
            PanelInfoRow { label: I18n.tr("quick.battery.model"); value: PowerService.model }
        }
    }
}
