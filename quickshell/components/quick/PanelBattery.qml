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
            title: "Battery"
            checked: false
            switchable: false
            onBackRequested: root.backRequested()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
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
                anchors.topMargin: 22
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
                anchors.topMargin: 14
                text: PowerService.present ? PowerService.level + "%" : "—"
                color: PowerService.present ? Theme.quickText : Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: percentText.bottom
                anchors.topMargin: 4
                text: {
                    if (!PowerService.present)
                        return "No battery detected";
                    if (PowerService.timeText === "")
                        return PowerService.stateText;
                    return PowerService.stateText + " · " + PowerService.timeText;
                }
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        PanelSection { text: "Power mode" }

        // power-profiles-daemon не отвечает: выбор режима невозможен, вместо
        // него — плашка с причиной и кнопкой повторной проверки.
        PanelWarning {
            width: parent.width
            visible: !PowerService.profilesAvailable
            height: visible ? implicitHeight : 0
            title: "Power modes unavailable"
            description: "power-profiles-daemon is not running"
            actionText: "Retry"
            onActionRequested: PowerService.probeProfiles()
        }

        // Режим питания: три сегмента, выбранный залит акцентом
        // (m3 segmented). Performance без поддержки железом неактивен.
        Item {
            width: parent.width
            height: PowerService.profilesAvailable ? 56 : 0
            visible: height > 0

            readonly property real segmentWidth: (width - 32 - 12) / 3

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: PowerService.profiles

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool available: PowerService.isProfileAvailable(modelData.value)
                        readonly property bool selected: PowerService.profile === modelData.value

                        width: parent.parent.segmentWidth
                        height: 36
                        radius: height / 2
                        color: selected ? Theme.accent : Theme.quickTile
                        opacity: available ? 1 : 0.45
                        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: selected ? Theme.quickIconOn : Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
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
            visible: PowerService.profilesAvailable && noteText.text !== ""
            height: visible ? noteText.implicitHeight : 0

            Text {
                id: noteText
                width: parent.width
                leftPadding: 16
                rightPadding: 16
                topPadding: 6
                bottomPadding: 8
                wrapMode: Text.WordWrap
                text: {
                    const parts = [];
                    if (PowerService.degradationText !== "")
                        parts.push(PowerService.degradationText);
                    if (PowerService.holdsText !== "")
                        parts.push(PowerService.holdsText);
                    return parts.join(" · ");
                }
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        // Подробности прячем целиком, если данных нет (нет батареи): пустой
        // заголовок секции выглядел бы недоделкой.
        Column {
            width: parent.width
            visible: root.hasDetails
            height: visible ? implicitHeight : 0
            spacing: 0

            PanelSection { text: "Details" }

            // Строки с пустым значением скрываются сами.
            PanelInfoRow { label: "Source"; value: PowerService.sourceText }
            PanelInfoRow { label: "Energy"; value: PowerService.energyText }
            PanelInfoRow { label: "Power draw"; value: PowerService.powerText }
            PanelInfoRow { label: "Health"; value: PowerService.healthText }
            PanelInfoRow { label: "Model"; value: PowerService.model }
        }
    }
}
