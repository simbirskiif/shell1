import QtQuick
import ".."
import "../../singletons"

// Панель «Конфиденциальность»: микрофон, камера и геолокация. Активные
// устройства — цветные expressive-карточки, неактивные — спокойные. Панель
// открывается кнопкой в баре, поэтому без активных устройств её с мыши не
// вызвать; клавиатурные и IPC-пути остаются.
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
            title: "Privacy"
            checked: PrivacyService.anyActive
            switchable: false
            onBackRequested: root.backRequested()
        }

        Item {
            width: parent.width
            height: Theme.space.xs
        }

        // Карточки идут с отступами по краям, но без разделителей:
        // состояние читается цветом, формой и весом шрифта.
        Item {
            width: parent.width
            implicitHeight: cards.implicitHeight
            height: implicitHeight

            Column {
                id: cards

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.space.md
                anchors.rightMargin: Theme.space.md
                spacing: Theme.space.sm

                PrivacyCard {
                    width: parent.width
                    icon: SystemIcons.microphoneGlyph
                    title: "Microphone"
                    subtitle: PrivacyService.microphoneStatus
                    active: PrivacyService.microphoneActive
                    available: PrivacyService.microphoneAvailable
                    accent: SystemIcons.microphoneColor
                    onAccent: SystemIcons.microphoneOnColor
                    container: SystemIcons.microphoneContainer
                    onContainer: SystemIcons.microphoneOnContainer
                }

                PrivacyCard {
                    width: parent.width
                    icon: SystemIcons.cameraGlyph
                    title: "Camera"
                    subtitle: PrivacyService.cameraStatus
                    active: PrivacyService.cameraActive
                    available: PrivacyService.cameraAvailable
                    accent: SystemIcons.cameraColor
                    onAccent: SystemIcons.cameraOnColor
                    container: SystemIcons.cameraContainer
                    onContainer: SystemIcons.cameraOnContainer
                }

                PrivacyCard {
                    width: parent.width
                    icon: SystemIcons.locationGlyph
                    title: "Location"
                    subtitle: PrivacyService.locationStatus
                    active: PrivacyService.locationActive
                    available: PrivacyService.locationAvailable
                    accent: SystemIcons.locationColor
                    onAccent: SystemIcons.locationOnColor
                    container: SystemIcons.locationContainer
                    onContainer: SystemIcons.locationOnContainer
                }
            }
        }

        // Подпись объясняет, почему в баре нет постоянных значков.
        Item {
            width: parent.width
            implicitHeight: hint.implicitHeight + Theme.space.lg * 2
            height: implicitHeight

            Text {
                id: hint

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.space.lg
                anchors.rightMargin: Theme.space.lg
                anchors.topMargin: Theme.space.lg
                text: "Only devices that are in use appear in the bar."
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
