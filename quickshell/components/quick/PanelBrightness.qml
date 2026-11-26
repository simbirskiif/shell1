import QtQuick
import ".."
import "../../singletons"

// Панель яркости: по строке на каждый экран композитора. Управляемые экраны
// получают слайдер, остальные — объяснение, почему яркость недоступна
// (нет backlight, не установлен ddcutil, монитор не умеет DDC/CI).
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
            title: I18n.tr("quick.tile.brightness")
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

        PanelDisabled {
            width: parent.width
            readonly property bool shown: BrightnessService.targets.length === 0
            visible: shown
            height: shown ? implicitHeight : 0
            icon: SystemIcons.brightnessGlyph
            title: I18n.tr("quick.brightness.noDisplays")
            description: I18n.tr("quick.brightness.noScreens")
            actionText: ""
            showAction: false
        }

        Column {
            id: content
            width: parent.width
            spacing: 0
            readonly property bool shown: BrightnessService.targets.length > 0
            visible: shown
            height: shown ? implicitHeight : 0

            Repeater {
                model: BrightnessService.targets

                delegate: BrightnessRow {
                    required property var modelData

                    width: content.width
                    label: modelData.label
                    subtitle: modelData.subtitle
                    controllable: modelData.controllable
                    hint: modelData.hint
                    value: BrightnessService.valueFor(modelData.key)
                    onMoved: v => BrightnessService.setValue(modelData.key, v)
                }
            }
        }
    }
}
