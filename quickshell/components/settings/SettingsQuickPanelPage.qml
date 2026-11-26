import QtQuick
import "../../singletons"

// Раздел «Быстрые настройки»: состав и порядок плиток. Сам попап по-прежнему
// умеет перетаскивать плитки, но все переключатели собраны здесь, чтобы
// настройка не пряталась в отдельном режиме.
SettingsPage {
    id: root

    title: I18n.tr("settings.quick.title")
    description: I18n.tr("settings.quick.description")

    function tileInfo(key) {
        if (key === "bluetooth")
            return { title: I18n.tr("quick.tile.bluetooth"), icon: "\uf293" };
        if (key === "internet")
            return { title: I18n.tr("quick.tile.internet"), icon: "\uf0ac" };
        if (key === "sound")
            return { title: I18n.tr("quick.tile.sound"), icon: "\uf028" };
        if (key === "dnd")
            return { title: I18n.tr("quick.tile.dnd"), icon: "\uf0f3" };
        if (key === "caffeine")
            return { title: I18n.tr("quick.tile.caffeine"), icon: "\uf0f4" };
        if (key === "brightness")
            return { title: I18n.tr("quick.tile.brightness"), icon: "\uf185" };
        if (key === "layout")
            return { title: I18n.tr("quick.tile.layout"), icon: "\uf00a" };
        return { title: key, icon: "\uf00a" };
    }

    SettingsCard {
        title: I18n.tr("settings.quick.visible.title")
        description: I18n.tr("settings.quick.visible.description")

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
            text: I18n.tr("settings.quick.allHidden")
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }
    }

    SettingsCard {
        title: I18n.tr("settings.quick.available.title")
        description: I18n.tr("settings.quick.available.description")

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
            text: I18n.tr("settings.quick.allShown")
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }
    }

    SettingsButton {
        text: I18n.tr("settings.quick.reset")
        variant: "outlined"
        onClicked: MockState.resetQuickTiles()
    }
}
