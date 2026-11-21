import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Панель питания: заряд батареи, состояние и время, выбор режима питания.
// Данные и действия — в PowerService (UPower и power-profiles-daemon).
// Если демон режимов недоступен, вместо сегментов показывается плашка.
//
// Expressive: процент — крупная цифра typeEmphasizedDisplaySmall в цветном
// контейнере, режимы — деформирующиеся пилюли, заголовки секций —
// typeEmphasizedTitleMedium, разделителей нет.
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

    // Режим питания: индексы и веса сегментов. Нажатый сегмент шире, активный
    // заметно шире остальных — группа «дышит» под пальцем (Expressive).
    property int pressedIndex: -1

    function segmentWeight(index) {
        const profile = PowerService.profiles[index];
        if (!profile)
            return 1.0;
        const selected = PowerService.profile === profile.value;
        if (index === root.pressedIndex)
            return selected ? 1.6 : 1.18;
        return selected ? 1.35 : 0.9;
    }

    readonly property real totalWeight: {
        let total = 0;
        for (let i = 0; i < PowerService.profiles.length; ++i)
            total += root.segmentWeight(i);
        return total > 0 ? total : 1;
    }

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: "Battery"
            checked: false
            switchable: false
            onBackRequested: root.backRequested()
        }

        // Заряд: «батарейка» с уровнем и крупный процент в цветном
        // контейнере — главный акцент панели.
        Item {
            width: parent.width
            height: 204

            MorphShape {
                anchors.fill: parent
                anchors.topMargin: Theme.space.xs
                anchors.bottomMargin: Theme.space.xs
                shape: "squircle"
                color: Theme.surfaceContainerHigh
                modulation: 0.45
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.space.xs + 2

                // Большая батарейка — тот же дизайн, что и в баре.
                BatteryIndicator {
                    id: batteryArt
                    anchors.horizontalCenter: parent.horizontalCenter
                    level: PowerService.level
                    charging: PowerService.charging
                    bodyWidth: 170
                    bodyHeight: 62
                    bodyRadius: 20
                    nubWidth: 8
                }

                // Процент: крупная цифра в «печеньке» primary/tertiary-контейнера.
                MorphShape {
                    id: percentChip
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 184
                    height: 88
                    shape: PowerService.charging ? "cookie" : "pill"
                    color: !PowerService.present ? Theme.surfaceContainerHighest
                         : PowerService.charging ? Theme.tertiaryContainer
                         : Theme.primaryContainer
                    modulation: PowerService.charging ? 0.8 : 0.45

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: PowerService.present ? PowerService.level + "%" : "—"
                        color: !PowerService.present ? Theme.scheme.onSurfaceVariant
                             : PowerService.charging ? Theme.scheme.onTertiaryContainer
                             : Theme.scheme.onPrimaryContainer
                        font: Theme.typeEmphasizedDisplaySmall
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!PowerService.present)
                            return "No battery detected";
                        if (PowerService.timeText === "")
                            return PowerService.stateText;
                        return PowerService.stateText + " · " + PowerService.timeText;
                    }
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }
            }
        }

        // --- Power mode ---------------------------------------------------
        Item {
            width: parent.width
            height: 44

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xs
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space.xs
                text: "Power mode"
                color: Theme.primary
                font: Theme.typeEmphasizedTitleMedium
            }
        }

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
            title: "Power modes unavailable"
            description: "power-profiles-daemon is not running"
            actionText: "Retry"
            onActionRequested: PowerService.probeProfiles()
        }

        // Режим питания: три Expressive-пилюли — активная шире и залита
        // tertiary-container, при нажатии группа деформируется. Performance
        // без поддержки железом неактивен.
        Item {
            width: parent.width
            height: PowerService.profilesAvailable ? 64 : 0
            visible: height > 0

            Row {
                id: segmentRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.space.md
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.xs + 2

                Repeater {
                    model: PowerService.profiles

                    delegate: Item {
                        required property var modelData
                        required property int index

                        readonly property bool available: PowerService.isProfileAvailable(modelData.value)
                        readonly property bool selected: PowerService.profile === modelData.value
                        readonly property bool pressed: root.pressedIndex === index
                        readonly property bool hovered: segmentHover.containsMouse

                        width: (segmentRow.width - segmentRow.spacing * 2)
                               * root.segmentWeight(index) / root.totalWeight
                        height: 54
                        opacity: available ? 1 : Theme.disabledContent

                        Behavior on width { SpringSpatial {} }
                        Behavior on opacity { SpringEffects {} }

                        MorphShape {
                            anchors.fill: parent
                            anchors.topMargin: 1
                            anchors.bottomMargin: 1
                            shape: selected ? "pill" : pressed ? "squircle" : "pill"
                            modulation: selected ? 0.4 : 0.3
                            color: selected ? Theme.tertiaryContainer
                                 : hovered ? Theme.surfaceContainerHighest
                                 : Theme.surfaceContainerHigh

                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - Theme.space.sm
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: modelData.label
                            color: selected ? Theme.scheme.onTertiaryContainer
                                            : Theme.scheme.onSurface
                            font: selected ? Theme.typeEmphasizedLabelLarge : Theme.typeLabelLarge
                            scale: pressed ? 0.96 : 1
                            Behavior on scale { SpringSpatialFast {} }
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        MouseArea {
                            id: segmentHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: available
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: root.pressedIndex = index
                            onReleased: root.pressedIndex = -1
                            onCanceled: root.pressedIndex = -1
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
            height: shown ? noteText.implicitHeight + Theme.space.sm : 0

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
                font: Theme.typeBodyMedium
            }
        }

        // --- Details ------------------------------------------------------
        // Подробности прячем целиком, если данных нет (нет батареи): пустой
        // заголовок секции выглядел бы недоделкой.
        Column {
            width: parent.width
            readonly property bool shown: root.hasDetails
            visible: shown
            height: shown ? implicitHeight : 0
            spacing: 0
            topPadding: Theme.space.xs

            Item {
                width: parent.width
                height: 44

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.xs
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.space.xs
                    text: "Details"
                    color: Theme.primary
                    font: Theme.typeEmphasizedTitleMedium
                }
            }

            // Строки с пустым значением скрываются сами.
            PanelInfoRow { label: "Source"; value: PowerService.sourceText }
            PanelInfoRow { label: "Energy"; value: PowerService.energyText }
            PanelInfoRow { label: "Power draw"; value: PowerService.powerText }
            PanelInfoRow { label: "Health"; value: PowerService.healthText }
            PanelInfoRow { label: "Model"; value: PowerService.model }
        }
    }
}
