import QtQuick
import "../../singletons"

// Раздел «Быстрые настройки»: состав и порядок плиток. Сам попап по-прежнему
// умеет перетаскивать плитки, но все переключатели собраны здесь, чтобы
// настройка не пряталась в отдельном режиме.
SettingsPage {
    id: root

    title: "Быстрые настройки"
    description: "Плитки в сетке: слева направо, сверху вниз."

    function tileInfo(key) {
        if (key === "bluetooth")
            return { title: "Bluetooth", icon: "\uf293" };
        if (key === "internet")
            return { title: "Интернет", icon: "\uf0ac" };
        if (key === "sound")
            return { title: "Звук", icon: "\uf028" };
        if (key === "dnd")
            return { title: "Не беспокоить", icon: "\uf0f3" };
        if (key === "caffeine")
            return { title: "Кофеин", icon: "\uf0f4" };
        if (key === "brightness")
            return { title: "Яркость", icon: "\uf185" };
        if (key === "layout")
            return { title: "Раскладка", icon: "\uf00a" };
        return { title: key, icon: "\uf00a" };
    }

    SettingsCard {
        title: "На панели"
        description: "Порядок можно менять стрелками."

        Repeater {
            model: MockState.visibleTiles

            delegate: Item {
                required property string modelData
                required property int index

                width: parent.width
                height: Theme.listItemHeight

                Text {
                    id: rowIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.space.xl
                    text: root.tileInfo(modelData).icon
                    color: Theme.scheme.onSurfaceVariant
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: rowActions.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.tileInfo(modelData).title
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                    elide: Text.ElideRight
                }

                Row {
                    id: rowActions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    SettingsIconButton {
                        icon: "\uf077"
                        enabled: index > 0
                        onClicked: MockState.moveVisibleTile(modelData, -1)
                    }

                    SettingsIconButton {
                        icon: "\uf078"
                        enabled: index < MockState.visibleTiles.length - 1
                        onClicked: MockState.moveVisibleTile(modelData, 1)
                    }

                    SettingsIconButton {
                        icon: "\uf070"
                        onClicked: MockState.hideQuickTile(modelData)
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: MockState.visibleTiles.length === 0
            text: "Все плитки скрыты"
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }
    }

    SettingsCard {
        title: "Доступные"
        description: "Скрытые плитки можно вернуть на панель."

        Repeater {
            model: MockState.availableTiles

            delegate: Item {
                required property string modelData

                width: parent.width
                height: Theme.listItemHeight

                Text {
                    id: rowIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.space.xl
                    text: root.tileInfo(modelData).icon
                    color: Theme.scheme.onSurfaceVariant
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: rowActions.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.tileInfo(modelData).title
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                    elide: Text.ElideRight
                }

                Row {
                    id: rowActions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    SettingsIconButton {
                        icon: "\uf067"
                        onClicked: MockState.showQuickTile(modelData)
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: MockState.availableTiles.length === 0
            text: "Все плитки уже на панели"
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }
    }

    SettingsButton {
        text: "Сбросить плитки"
        variant: "outlined"
        onClicked: MockState.resetQuickTiles()
    }
}
