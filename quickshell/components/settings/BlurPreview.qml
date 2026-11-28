import QtQuick
import "../../singletons"
import "../../widgets/core"
import "../effects"

// Живой пример к настройкам «Блюр и карточки»: фон размывается тем же
// dual Kawase, а карточка использует ту же тонировку, что панели оболочки.
// Появляется при движении ползунков и гаснет сам (SettingsWindowState).
Item {
    id: root

    width: 340
    height: 230

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.lg
        color: Theme.menuSurfaceSolid
        border.width: 1
        border.color: Theme.outlineVariant
    }

    Text {
        id: title

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Theme.space.md
        anchors.topMargin: Theme.space.sm
        text: I18n.tr("settings.appearance.blur.preview.title")
        color: Theme.scheme.onSurface
        font: Theme.typeLabelLarge
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: title.verticalCenter
        anchors.rightMargin: Theme.space.md
        text: I18n.tr("settings.appearance.blur.preview.values", {
            blur: Math.round(Theme.blurStrength * 100),
            contrast: Math.round(Theme.cardContrast * 100)
        })
        color: Theme.primary
        font: Theme.typeLabelSmall
    }

    Rectangle {
        id: viewport

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.space.sm
        anchors.rightMargin: Theme.space.sm
        anchors.topMargin: Theme.space.xs
        anchors.bottomMargin: Theme.space.sm
        radius: Theme.shape.md
        clip: true
        color: Theme.surfaceContainerLowest

        Image {
            id: wallpaper

            anchors.fill: parent
            source: Wallpaper.sourceUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            sourceSize.width: 480
            sourceSize.height: 320
            visible: false
        }

        ShaderEffectSource {
            id: wallpaperTexture

            sourceItem: wallpaper
            width: Math.max(1, wallpaper.width)
            height: Math.max(1, wallpaper.height)
            hideSource: true
            live: root.visible
            visible: false
        }

        // Пока обои не загрузились (или их нет) — тональный градиент.
        Rectangle {
            anchors.fill: parent
            visible: wallpaper.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.primaryContainer }
                GradientStop { position: 1.0; color: Theme.tertiaryContainer }
            }
        }

        KawaseBlur {
            anchors.fill: parent
            sourceItem: wallpaperTexture
            live: root.visible
            visible: wallpaper.status === Image.Ready
            blurRadius: Theme.blurRadius(36)
            saturation: 1.06
        }

        // Мини-панель: та же полупрозрачная подложка, что у настоящих
        // карточек. За ней видно размытый фон — это и есть пример.
        Rectangle {
            id: sample

            anchors.fill: parent
            anchors.margins: Theme.space.md
            radius: Theme.shape.md
            color: Theme.sheetBlurSurface
            border.width: 1
            border.color: Theme.outlineVariant

            Column {
                anchors.fill: parent
                anchors.margins: Theme.space.md
                spacing: Theme.space.sm

                Row {
                    spacing: Theme.space.sm

                    Text {
                        text: "\uf013"
                        color: Theme.scheme.onSurface
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.md
                    }

                    Text {
                        text: I18n.tr("quick.title")
                        color: Theme.scheme.onSurface
                        font: Theme.typeLabelLarge
                    }
                }

                // Плитка внутри карточки — пример того, что контраст
                // действует и на элементы выше blur.
                Rectangle {
                    width: parent.width
                    height: rows.implicitHeight + Theme.space.sm * 2
                    radius: Theme.shape.sm
                    color: Theme.blurInnerCard(Theme.surfaceContainerHigh)

                    Column {
                        id: rows

                        anchors.fill: parent
                        anchors.margins: Theme.space.sm
                        spacing: Theme.space.xs

                        Row {
                            spacing: Theme.space.sm

                            Text {
                                text: "\uf1eb"
                                color: Theme.primary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.iconSize.md
                            }

                            Text {
                                text: I18n.tr("quick.tile.wifi")
                                color: Theme.scheme.onSurface
                                font: Theme.typeBodyMedium
                            }
                        }

                        Row {
                            spacing: Theme.space.sm

                            Text {
                                text: "\uf028"
                                color: Theme.primary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.iconSize.md
                            }

                            Text {
                                text: I18n.tr("quick.tile.sound")
                                color: Theme.scheme.onSurface
                                font: Theme.typeBodyMedium
                            }
                        }
                    }
                }
            }
        }
    }
}
