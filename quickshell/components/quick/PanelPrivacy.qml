import QtQuick
import ".."
import "../../singletons"

// Панель «Конфиденциальность»: текущее использование устройств и история
// сессий. Активные устройства — цветные expressive-карточки с кнопкой
// остановки, неактивные — спокойные.
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
                    stoppable: PrivacyService.microphoneStoppable
                    accent: SystemIcons.microphoneColor
                    onAccent: SystemIcons.microphoneOnColor
                    container: SystemIcons.microphoneContainer
                    onContainer: SystemIcons.microphoneOnContainer
                    onStopRequested: PrivacyService.stopDevice("microphone")
                }

                PrivacyCard {
                    width: parent.width
                    icon: SystemIcons.cameraGlyph
                    title: "Camera"
                    subtitle: PrivacyService.cameraStatus
                    active: PrivacyService.cameraActive
                    available: PrivacyService.cameraAvailable
                    stoppable: PrivacyService.cameraStoppable
                    accent: SystemIcons.cameraColor
                    onAccent: SystemIcons.cameraOnColor
                    container: SystemIcons.cameraContainer
                    onContainer: SystemIcons.cameraOnContainer
                    onStopRequested: PrivacyService.stopDevice("camera")
                }

                PrivacyCard {
                    width: parent.width
                    icon: SystemIcons.locationGlyph
                    title: "Location"
                    subtitle: PrivacyService.locationStatus
                    active: PrivacyService.locationActive
                    available: PrivacyService.locationAvailable
                    stoppable: PrivacyService.locationStoppable
                    accent: SystemIcons.locationColor
                    onAccent: SystemIcons.locationOnColor
                    container: SystemIcons.locationContainer
                    onContainer: SystemIcons.locationOnContainer
                    onStopRequested: PrivacyService.stopDevice("location")
                }
            }
        }

        Item {
            width: parent.width
            height: Theme.space.sm
        }

        // История: последние сессии-«пакеты», новые сверху.
        Item {
            width: parent.width
            height: Theme.quickSectionHeight

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                text: "History"
                color: Theme.primary
                font: Theme.typeLabelLarge
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                visible: PrivacyService.history.length > 0
                width: clearLabel.implicitWidth + Theme.space.lg * 2
                height: 32
                radius: Theme.shape.full
                color: clearHover.containsMouse
                       ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                       : "transparent"

                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear"
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeLabelLarge
                }

                MouseArea {
                    id: clearHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PrivacyService.clearHistory()
                }
            }
        }

        Item {
            width: parent.width
            implicitHeight: historyEmpty.visible
                ? historyEmpty.implicitHeight + Theme.space.sm : historyList.implicitHeight
            height: implicitHeight

            Text {
                id: historyEmpty
                visible: PrivacyService.recentHistory.length === 0
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.lg
                anchors.top: parent.top
                text: "No sessions yet."
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
            }

            Column {
                id: historyList
                visible: PrivacyService.recentHistory.length > 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.space.md
                anchors.rightMargin: Theme.space.md
                spacing: 6

                Repeater {
                    model: PrivacyService.recentHistory

                    delegate: PrivacyHistoryRow {
                        required property var modelData

                        width: parent.width
                        device: modelData.device
                        apps: modelData.apps
                        start: modelData.start
                        end: modelData.end
                    }
                }
            }
        }

        // Подпись объясняет ограничения остановки и поведение бара.
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
                text: "Only devices that are in use appear in the bar. Stop ends the app's PipeWire capture; V4L2 cameras and GeoClue can't be revoked from the shell."
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
