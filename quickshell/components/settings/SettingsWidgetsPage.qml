import QtQuick
import "../../singletons"
import "../../widgets/core"

// Раздел «Виджеты»: значения по умолчанию для всех экземпляров, сетка и
// вход в редактор раскладки. Параметры конкретного экземпляра по-прежнему
// открываются по ПКМ на самом виджете — они привязаны к его uid.
SettingsPage {
    id: root

    property string message: ""

    function materialOptions() {
        const result = [];
        for (let i = 0; i < MaterialRegistry.materials.length; ++i) {
            const material = MaterialRegistry.materials[i];
            result.push({ key: material.id, label: material.name });
        }
        return result;
    }

    title: "Виджеты"
    description: "Общие параметры для экземпляров, которые не переопределили их сами."

    SettingsCard {
        title: "По умолчанию"

        SettingsChoice {
            title: "Материал"
            options: root.materialOptions()
            value: Config.defaultMaterial
            onSelected: key => {
                if (Config.setDefaultMaterial(key))
                    root.message = "Материал по умолчанию: " + key;
            }
        }

        SettingsChoice {
            title: "Цвет"
            options: [
                { key: "accent", label: "Акцент" },
                { key: "neutral", label: "Нейтральная" }
            ]
            value: Config.defaultColorMode
            onSelected: key => {
                if (Config.setDefaultColorMode(key))
                    root.message = "Цвет по умолчанию: " + key;
            }
        }

        SettingsSliderRow {
            title: "Затемнение материала"
            description: "Насколько плотно материал закрывает подложку"
            value: (Config.defaultMaterialDim - 0.10) / 0.85
            valueText: Math.round(Config.defaultMaterialDim * 100) + "%"
            onMoved: v => Config.setDefaultMaterialDim(0.10 + v * 0.85)
        }
    }

    SettingsCard {
        title: "Сетка"

        SettingsSwitchRow {
            title: "Показывать сетку"
            description: "Отладочная разметка рабочего стола"
            checked: Config.showGrid
            onToggled: Config.setShowGrid(!Config.showGrid)
        }
    }

    SettingsCard {
        title: "Раскладка"

        Text {
            width: parent.width
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
            text: "Перемещение, размер и параметры отдельного виджета — в режиме "
                  + "редактирования рабочего стола (ПКМ по пустому месту)."
        }

        Row {
            spacing: Theme.space.sm

            SettingsButton {
                text: "Открыть редактор"
                variant: "filled"
                onClicked: {
                    SettingsWindowState.close();
                    EditorState.enter();
                }
            }

            SettingsButton {
                text: "Сбросить переопределения"
                variant: "outlined"
                onClicked: {
                    EditorState.beginOperation();
                    const count = LayoutStore.clearOverrides();
                    root.message = count > 0
                                 ? "Сброшено переопределений: " + count
                                 : "Переопределений нет";
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
