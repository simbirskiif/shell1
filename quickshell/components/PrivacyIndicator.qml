import QtQuick
import "../singletons"

// Кнопки конфиденциальности в баре: по одной на активное устройство.
// Показываются только те, что используются; у микрофона, камеры и
// геолокации свои цвета (SystemIcons). Пустое состояние в баре скрыто
// полностью, поэтому в предпросмотре настроек рисуется нейтральный щит.
Row {
    id: root

    // Настройки показывают элемент даже без активных устройств: иначе
    // его нельзя было бы выбрать и перетащить.
    property bool previewMode: false
    // В баре орбы сами ловят клик; в строке быстрых настроек кликается
    // вся строка, поэтому интерактивность выключается.
    property bool interactive: true
    // Пользовательская иконка заменяет группу одним орбом.
    property string iconOverride: ""

    signal clicked()

    readonly property bool custom: root.iconOverride !== ""
    readonly property bool showCustom: root.custom
        && (root.previewMode || PrivacyService.anyActive)

    // Орбы идут по той же сетке, что кнопки бара: слот 40 и зазор 4.
    spacing: Theme.barIconGap

    PrivacyOrb {
        visible: root.showCustom
        icon: root.iconOverride
        accent: Theme.primary
        onAccent: Theme.scheme.onPrimary
        // В покое — нейтральный орб, при использовании — акцентный.
        active: PrivacyService.anyActive
        animated: false
        interactive: root.interactive && !root.previewMode
        onClicked: root.clicked()
    }

    PrivacyOrb {
        visible: !root.custom && PrivacyService.microphoneActive
        icon: SystemIcons.microphoneGlyph
        accent: SystemIcons.microphoneColor
        onAccent: SystemIcons.microphoneOnColor
        active: PrivacyService.microphoneActive
        interactive: root.interactive && !root.previewMode
        onClicked: root.clicked()
    }

    PrivacyOrb {
        visible: !root.custom && PrivacyService.cameraActive
        icon: SystemIcons.cameraGlyph
        accent: SystemIcons.cameraColor
        onAccent: SystemIcons.cameraOnColor
        active: PrivacyService.cameraActive
        interactive: root.interactive && !root.previewMode
        onClicked: root.clicked()
    }

    PrivacyOrb {
        visible: !root.custom && PrivacyService.screenActive
        icon: SystemIcons.screenGlyph
        accent: SystemIcons.screenColor
        onAccent: SystemIcons.screenOnColor
        active: PrivacyService.screenActive
        interactive: root.interactive && !root.previewMode
        onClicked: root.clicked()
    }

    PrivacyOrb {
        visible: !root.custom && PrivacyService.locationActive
        icon: SystemIcons.locationGlyph
        accent: SystemIcons.locationColor
        onAccent: SystemIcons.locationOnColor
        active: PrivacyService.locationActive
        interactive: root.interactive && !root.previewMode
        onClicked: root.clicked()
    }

    // Предпросмотр в настройках без активных устройств: показываем, что
    // элемент существует, спокойным щитом без цвета.
    PrivacyOrb {
        visible: root.previewMode && !root.custom && !PrivacyService.anyActive
        icon: "\uf132"
        active: false
        animated: false
        interactive: false
    }
}
