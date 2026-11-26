import QtQuick
import "../singletons"

// Кнопка конфиденциальности в баре: микрофон, камера и геолокация.
// Значки видны всегда, пока устройство/сервис существует, и загораются
// акцентом, когда кто-то их использует. Нажатие открывает панель.
Rectangle {
    id: root

    // Пользовательская иконка из настроек: заменяет всю группу значков.
    property string iconOverride: ""

    signal clicked()

    readonly property bool custom: root.iconOverride !== ""
    readonly property bool active: PrivacyService.anyActive

    implicitWidth: content.implicitWidth + 24
    implicitHeight: Theme.iconButtonSize
    radius: Theme.controlRadius
    // Пока что-то используется, кнопка слегка подсвечена — её видно
    // боковым зрением, даже не разбирая значки.
    color: root.active
           ? Theme.withAlpha(Theme.primary, 0.12)
           : (hover.containsMouse
              ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
              : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    Row {
        id: content

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        spacing: 6
        visible: !root.custom

        // Микрофон: значок есть, только если в системе есть вход.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: PrivacyService.microphoneAvailable
            text: "\uf130"
            color: PrivacyService.microphoneActive ? Theme.primary
                                                    : Theme.scheme.onSurfaceVariant
            opacity: PrivacyService.microphoneActive ? 1 : 0.55
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort4 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: PrivacyService.cameraAvailable
            text: "\uf030"
            color: PrivacyService.cameraActive ? Theme.primary
                                                : Theme.scheme.onSurfaceVariant
            opacity: PrivacyService.cameraActive ? 1 : 0.55
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort4 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: PrivacyService.locationAvailable
            text: "\uf041"
            color: PrivacyService.locationActive ? Theme.primary
                                                  : Theme.scheme.onSurfaceVariant
            opacity: PrivacyService.locationActive ? 1 : 0.55
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort4 } }
        }

        // Ни микрофона, ни камеры, ни GeoClue (например, минимальный
        // десктоп): кнопка всё равно должна быть видна и открывать панель.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !PrivacyService.anyAvailable
            text: "\uf132"
            color: Theme.scheme.onSurfaceVariant
            opacity: 0.55
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.custom
        text: root.iconOverride
        color: root.active ? Theme.primary : Theme.scheme.onSurface
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.sm
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
