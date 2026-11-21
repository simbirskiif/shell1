import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Панель яркости: по строке на каждый экран композитора. Управляемые экраны
// получают слайдер, остальные — объяснение, почему яркость недоступна
// (нет backlight, не установлен ddcutil, монитор не умеет DDC/CI).
//
// Expressive: строки — крупные блоки с орбом-sunny и волнистым слайдером
// tertiary-акцента; разделителей нет, группы разделяет воздух.
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
            title: "Brightness"
            checked: false
            switchable: false
            onBackRequested: root.backRequested()
        }

        PanelDisabled {
            width: parent.width
            readonly property bool shown: BrightnessService.targets.length === 0
            visible: shown
            height: shown ? implicitHeight : 0
            icon: "\uf185"
            title: "No displays"
            description: "The compositor reported no screens"
            actionText: ""
            showAction: false
        }

        Column {
            id: content
            width: parent.width
            spacing: Theme.space.xs
            topPadding: Theme.space.xs
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
