import QtQuick
import "../../singletons"

// Раздел «Кофеин»: строка допустимых сроков. Окно настроек само держит
// клавиатурный фокус, поэтому правка идёт прямо здесь, без отдельного
// InputDialog.
SettingsPage {
    id: root

    title: I18n.tr("settings.caffeine.title")
    description: I18n.tr("settings.caffeine.description")

    function commit(text) {
        root.applied = text;
        CaffeineService.durations = text;
    }

    property string applied: CaffeineService.durations

    Component.onCompleted: root.applied = CaffeineService.durations

    SettingsCard {
        title: I18n.tr("settings.caffeine.durations.title")
        description: I18n.tr("settings.caffeine.durations.description")

        Item {
            width: parent.width
            height: Theme.listItemHeight

            Rectangle {
                id: fieldFrame

                anchors.left: parent.left
                anchors.right: applyButton.left
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.listItemHeight
                radius: Theme.shape.xs
                color: Theme.surfaceContainerHighest
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? Theme.primary : Theme.outline
                Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                TextInput {
                    id: field

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.space.lg
                    text: CaffeineService.durations
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                    selectByMouse: true
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.scheme.onPrimary

                    onAccepted: root.commit(text)
                    onActiveFocusChanged: {
                        if (!activeFocus)
                            root.commit(text);
                    }
                }
            }

            SettingsButton {
                id: applyButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("common.apply")
                variant: "tonal"
                onClicked: root.commit(field.text)
            }
        }

        Text {
            width: parent.width
            text: CaffeineService.options.length > 0
                  ? I18n.tr("settings.caffeine.current",
                            { list: CaffeineService.options.map(o => o.title).join(" · ") })
                  : I18n.tr("settings.caffeine.parseError")
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        title: I18n.tr("settings.caffeine.state.title")

        SettingsRow {
            title: I18n.tr("settings.caffeine.mode.title")
            description: CaffeineService.expiresAt > 0
                         ? I18n.tr("settings.caffeine.mode.timed")
                         : (CaffeineService.active ? I18n.tr("settings.caffeine.mode.untilOff")
                                                   : I18n.tr("settings.caffeine.mode.off"))

            Text {
                text: CaffeineService.label
                color: CaffeineService.active ? Theme.primary : Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelLarge
            }
        }
    }

    SettingsButton {
        text: I18n.tr("settings.caffeine.reset")
        variant: "outlined"
        onClicked: {
            root.commit("30, 1h, 2h");
            field.text = CaffeineService.durations;
        }
    }
}
