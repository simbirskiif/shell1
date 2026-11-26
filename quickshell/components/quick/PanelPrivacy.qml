import QtQuick
import ".."
import "../../singletons"

// Панель «Конфиденциальность»: микрофон, камера и геолокация — кто их
// сейчас использует. Состояние приходит из PrivacyService (PipeWire и
// helper камеры/GeoClue), здесь только показ.
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

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PrivacyRow {
            icon: "\uf130"
            title: "Microphone"
            subtitle: PrivacyService.microphoneStatus
            active: PrivacyService.microphoneActive
            available: PrivacyService.microphoneAvailable
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PrivacyRow {
            icon: "\uf030"
            title: "Camera"
            subtitle: PrivacyService.cameraStatus
            active: PrivacyService.cameraActive
            available: PrivacyService.cameraAvailable
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PrivacyRow {
            icon: "\uf041"
            title: "Location"
            subtitle: PrivacyService.locationStatus
            active: PrivacyService.locationActive
            available: PrivacyService.locationAvailable
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        // Пояснение к значкам в баре: тусклый — доступен, акцентный — в работе.
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
                text: "In the bar, dimmed icons are available and highlighted icons are in use."
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
