import QtQuick
import "../../singletons"

// Отдельное модальное окно выбора иконки элемента бара. Живёт поверх
// всей карточки настроек, поэтому список иконок не загромождает раздел
// «Бар». Для «Пункта управления» здесь же настраиваются три входящих значка.
Item {
    id: root

    anchors.fill: parent
    visible: SettingsWindowState.iconEditorKey !== ""
    z: 300

    readonly property string key: SettingsWindowState.iconEditorKey

    function titleFor(key) {
        return I18n.trOr("bar.item." + key, MockState.barItemTitles[key] || key);
    }

    function iconOptions(key) {
        if (key === "battery") {
            return [
                { glyph: "", labelKey: "settings.barIcon.label.auto" },
                { glyph: "\uf240", labelKey: "settings.barIcon.label.full" },
                { glyph: "\uf241", labelKey: "settings.barIcon.label.threeQuarters" },
                { glyph: "\uf242", labelKey: "settings.barIcon.label.half" },
                { glyph: "\uf243", labelKey: "settings.barIcon.label.quarter" },
                { glyph: "\uf244", labelKey: "settings.barIcon.label.empty" },
                { glyph: "\uf0e7", labelKey: "settings.barIcon.label.bolt" },
                { glyph: "\uf1e6", labelKey: "settings.barIcon.label.plug" }
            ];
        }
        if (key === "notifications") {
            return [
                { glyph: "", labelKey: "settings.barIcon.label.auto" },
                { glyph: "\uf0f3", labelKey: "settings.barIcon.label.bell" },
                { glyph: "\uf1f6", labelKey: "settings.barIcon.label.silent" },
                { glyph: "\uf0e0", labelKey: "settings.barIcon.label.envelope" },
                { glyph: "\uf27a", labelKey: "settings.barIcon.label.message" },
                { glyph: "\uf12a", labelKey: "settings.barIcon.label.important" },
                { glyph: "\uf024", labelKey: "settings.barIcon.label.flag" },
                { glyph: "\uf111", labelKey: "settings.barIcon.label.dot" }
            ];
        }
        if (key === "wifi") {
            return [
                { glyph: "", labelKey: "settings.barIcon.label.auto" },
                { glyph: "\uf1eb", labelKey: "settings.barIcon.label.wifi" },
                { glyph: "\uf0ac", labelKey: "settings.barIcon.label.globe" },
                { glyph: "\uf012", labelKey: "settings.barIcon.label.signal" }
            ];
        }
        if (key === "bluetooth") {
            return [
                { glyph: "", labelKey: "settings.barIcon.label.auto" },
                { glyph: "\uf293", labelKey: "settings.barIcon.label.bluetooth" },
                { glyph: "\uf294", labelKey: "settings.barIcon.label.bluetoothB" },
                { glyph: "\uf10b", labelKey: "settings.barIcon.label.device" }
            ];
        }
        if (key === "brightness") {
            return [
                { glyph: "", labelKey: "settings.barIcon.label.auto" },
                { glyph: "\uf185", labelKey: "settings.barIcon.label.sun" },
                { glyph: "\uf186", labelKey: "settings.barIcon.label.sun2" },
                { glyph: "\uf0eb", labelKey: "settings.barIcon.label.lamp" },
                { glyph: "\uf042", labelKey: "settings.barIcon.label.contrast" }
            ];
        }
        if (key === "sound") {
            return [
                { glyph: "", labelKey: "settings.barIcon.label.auto" },
                { glyph: "\uf028", labelKey: "settings.barIcon.label.sound" },
                { glyph: "\uf027", labelKey: "settings.barIcon.label.quieter" },
                { glyph: "\uf026", labelKey: "settings.barIcon.label.muted" },
                { glyph: "\uf130", labelKey: "settings.barIcon.label.microphone" }
            ];
        }
        if (key === "privacy") {
            return [
                { glyph: "", labelKey: "settings.barIcon.label.auto" },
                { glyph: "\uf132", labelKey: "settings.barIcon.label.shield" },
                { glyph: "\uf130", labelKey: "settings.barIcon.label.microphone" },
                { glyph: "\uf030", labelKey: "settings.barIcon.label.camera" },
                { glyph: "\uf108", labelKey: "settings.barIcon.label.screen" },
                { glyph: "\uf041", labelKey: "settings.barIcon.label.location" },
                { glyph: "\uf06e", labelKey: "settings.barIcon.label.eye" },
                { glyph: "\uf070", labelKey: "settings.barIcon.label.eyeOff" }
            ];
        }
        if (key === "player") {
            return [
                { glyph: "", labelKey: "settings.barIcon.label.auto" },
                { glyph: "\uf001", labelKey: "settings.barIcon.label.note" },
                { glyph: "\uf025", labelKey: "settings.barIcon.label.headphones" },
                { glyph: "\uf008", labelKey: "settings.barIcon.label.playlist" },
                { glyph: "\uf03e", labelKey: "settings.barIcon.label.artwork" }
            ];
        }
        return [{ glyph: "", labelKey: "settings.barIcon.label.auto" }];
    }

    function statusOptions(slot) {
        if (slot === "wifi") {
            return [
                { value: "auto", glyph: "\uf021", labelKey: "settings.barIcon.label.auto" },
                { value: "", glyph: "\uf070", labelKey: "settings.barIcon.label.hide" },
                { value: "\uf1eb", glyph: "\uf1eb", labelKey: "" },
                { value: "\uf0ac", glyph: "\uf0ac", labelKey: "" },
                { value: "\uf012", glyph: "\uf012", labelKey: "" }
            ];
        }
        if (slot === "bluetooth") {
            return [
                { value: "auto", glyph: "\uf021", labelKey: "settings.barIcon.label.auto" },
                { value: "", glyph: "\uf070", labelKey: "settings.barIcon.label.hide" },
                { value: "\uf293", glyph: "\uf293", labelKey: "" },
                { value: "\uf294", glyph: "\uf294", labelKey: "" }
            ];
        }
        return [
            { value: "auto", glyph: "\uf021", labelKey: "settings.barIcon.label.auto" },
            { value: "", glyph: "\uf070", labelKey: "settings.barIcon.label.hide" },
            { value: "\uf028", glyph: "\uf028", labelKey: "" },
            { value: "\uf026", glyph: "\uf026", labelKey: "" },
            { value: "\uf130", glyph: "\uf130", labelKey: "" }
        ];
    }

    function close() {
        SettingsWindowState.closeIconEditor();
    }

    function resetIcon() {
        if (root.key === "status")
            MockState.resetStatusIcons();
        else
            MockState.setBarIcon(root.key, "");
    }

    // Затемнение поверх всей карточки настроек.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrimOverlay

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.max(360, Math.min(560, parent.width - Theme.space.xxxl * 2))
        height: Math.min(parent.height - Theme.space.xxxl * 2,
                         Math.max(320, Theme.space.xl * 2 + header.implicitHeight
                                  + Theme.space.lg + contentColumn.implicitHeight
                                  + Theme.space.lg + footer.height))
        radius: Theme.shape.xl
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.space.xl
            spacing: Theme.space.xs

            Text {
                width: parent.width - closeButton.width - Theme.space.md
                text: I18n.tr("settings.barIcon.title", { name: root.titleFor(root.key) })
                color: Theme.scheme.onSurface
                font: Theme.typeTitleLarge
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.key === "status"
                      ? I18n.tr("settings.barIcon.status.description")
                      : I18n.tr("settings.barIcon.description")
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: closeButton

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.space.lg
            anchors.rightMargin: Theme.space.lg
            width: Theme.iconButtonSize
            height: Theme.iconButtonSize

            Rectangle {
                anchors.fill: parent
                radius: Theme.shape.full
                color: closeHover.containsMouse
                       ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: Theme.scheme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: Theme.iconSize.lg
            }

            MouseArea {
                id: closeHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
            }
        }

        Flickable {
            id: contentScroll

            anchors.top: header.bottom
            anchors.topMargin: Theme.space.lg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.bottomMargin: Theme.space.md
            anchors.leftMargin: Theme.space.xl
            anchors.rightMargin: Theme.space.xl
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: contentColumn

                width: contentScroll.width
                spacing: Theme.space.lg

                Column {
                    width: parent.width
                    spacing: Theme.space.md
                    visible: root.key === "status"

                    BarSlotIconChoice {
                        width: parent.width
                        title: "Wi-Fi"
                        options: root.statusOptions("wifi")
                        value: MockState.statusIconFor("wifi")
                        onPicked: value => MockState.setStatusIcon("wifi", value)
                    }

                    BarSlotIconChoice {
                        width: parent.width
                        title: "Bluetooth"
                        options: root.statusOptions("bluetooth")
                        value: MockState.statusIconFor("bluetooth")
                        onPicked: value => MockState.setStatusIcon("bluetooth", value)
                    }

                    BarSlotIconChoice {
                        width: parent.width
                        title: I18n.tr("settings.barIcon.slot.sound")
                        options: root.statusOptions("sound")
                        value: MockState.statusIconFor("sound")
                        onPicked: value => MockState.setStatusIcon("sound", value)
                    }
                }

                BarIconPicker {
                    width: parent.width
                    visible: root.key !== "status"
                    options: root.iconOptions(root.key)
                    selectedGlyph: MockState.iconOverrideFor(root.key)
                    onPicked: glyph => MockState.setBarIcon(root.key, glyph)
                }
            }
        }

        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.space.lg
            height: Theme.buttonHeight

            SettingsButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("common.reset")
                variant: "outlined"
                onClicked: root.resetIcon()
            }

            SettingsButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("common.done")
                variant: "filled"
                onClicked: root.close()
            }
        }
    }
}
