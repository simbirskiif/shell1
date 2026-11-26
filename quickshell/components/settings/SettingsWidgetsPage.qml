import QtQuick
import "../../singletons"
import "../../widgets/core"

// Раздел «Виджеты»: значения по умолчанию для всех экземпляров, сетка и
// вход в редактор раскладки. Параметры конкретного экземпляра по-прежнему
// открываются по ПКМ на самом виджете — они привязаны к его uid.
SettingsPage {
    id: root

    property string message: ""

    function materialLabel(id) {
        for (let i = 0; i < MaterialRegistry.materials.length; ++i) {
            const material = MaterialRegistry.materials[i];
            if (material.id === id)
                return I18n.trOr("material." + id + ".name", material.name);
        }
        return id;
    }

    function materialOptions() {
        const result = [];
        for (let i = 0; i < MaterialRegistry.materials.length; ++i) {
            const material = MaterialRegistry.materials[i];
            result.push({ key: material.id, label: root.materialLabel(material.id) });
        }
        return result;
    }

    title: I18n.tr("settings.widgets.title")
    description: I18n.tr("settings.widgets.description")

    SettingsCard {
        title: I18n.tr("settings.widgets.defaults.title")

        SettingsChoice {
            title: I18n.tr("widgets.material")
            options: root.materialOptions()
            value: Config.defaultMaterial
            onSelected: key => {
                if (Config.setDefaultMaterial(key))
                    root.message = I18n.tr("settings.widgets.materialChanged",
                                           { name: root.materialLabel(key) });
            }
        }

        SettingsChoice {
            title: I18n.tr("widgets.colorMode")
            options: [
                { key: "accent", label: I18n.tr("widgets.colorMode.accent") },
                { key: "neutral", label: I18n.tr("widgets.colorMode.neutral") }
            ]
            value: Config.defaultColorMode
            onSelected: key => {
                if (Config.setDefaultColorMode(key))
                    root.message = I18n.tr("settings.widgets.colorChanged",
                                           { color: I18n.tr("widgets.colorMode." + key) });
            }
        }

        SettingsSliderRow {
            title: I18n.tr("widgets.materialDim")
            description: I18n.tr("settings.widgets.materialDim.description")
            value: (Config.defaultMaterialDim - 0.10) / 0.85
            valueText: Math.round(Config.defaultMaterialDim * 100) + "%"
            onMoved: v => Config.setDefaultMaterialDim(0.10 + v * 0.85)
        }
    }

    SettingsCard {
        title: I18n.tr("settings.widgets.grid.title")

        SettingsSwitchRow {
            title: I18n.tr("settings.widgets.grid.show.title")
            description: I18n.tr("settings.widgets.grid.show.description")
            checked: Config.showGrid
            onToggled: Config.setShowGrid(!Config.showGrid)
        }
    }

    SettingsCard {
        title: I18n.tr("settings.widgets.layout.title")

        Text {
            width: parent.width
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
            text: I18n.tr("settings.widgets.layout.description")
        }

        Row {
            spacing: Theme.space.sm

            SettingsButton {
                text: I18n.tr("settings.widgets.openEditor")
                variant: "filled"
                onClicked: {
                    SettingsWindowState.close();
                    EditorState.enter();
                }
            }

            SettingsButton {
                text: I18n.tr("settings.widgets.clearOverrides")
                variant: "outlined"
                onClicked: {
                    EditorState.beginOperation();
                    const count = LayoutStore.clearOverrides();
                    root.message = count > 0
                                 ? I18n.trn("settings.widgets.overridesCleared", count)
                                 : I18n.tr("settings.widgets.noOverrides");
                }
            }
        }

        Text {
            width: parent.width
            visible: root.message !== ""
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
            text: root.message
        }
    }
}
