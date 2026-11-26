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
        return MockState.barItemTitles[key] || key;
    }

    function iconOptions(key) {
        if (key === "battery") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf240", label: "Полная" },
                { glyph: "\uf241", label: "3/4" },
                { glyph: "\uf242", label: "1/2" },
                { glyph: "\uf243", label: "1/4" },
                { glyph: "\uf244", label: "Пустая" },
                { glyph: "\uf0e7", label: "Молния" },
                { glyph: "\uf1e6", label: "Вилка" }
            ];
        }
        if (key === "notifications") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf0f3", label: "Колокол" },
                { glyph: "\uf1f6", label: "Без звука" },
                { glyph: "\uf0e0", label: "Конверт" },
                { glyph: "\uf27a", label: "Сообщение" },
                { glyph: "\uf12a", label: "Важно" },
                { glyph: "\uf024", label: "Флаг" },
                { glyph: "\uf111", label: "Точка" }
            ];
        }
        if (key === "wifi") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf1eb", label: "Wi-Fi" },
                { glyph: "\uf0ac", label: "Глобус" },
                { glyph: "\uf012", label: "Сигнал" }
            ];
        }
        if (key === "bluetooth") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf293", label: "Bluetooth" },
                { glyph: "\uf294", label: "Bluetooth B" },
                { glyph: "\uf10b", label: "Устройство" }
            ];
        }
        if (key === "brightness") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf185", label: "Солнце" },
                { glyph: "\uf186", label: "Солнце 2" },
                { glyph: "\uf0eb", label: "Лампа" },
                { glyph: "\uf042", label: "Контраст" }
            ];
        }
        if (key === "sound") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf028", label: "Звук" },
                { glyph: "\uf027", label: "Тише" },
                { glyph: "\uf026", label: "Выключен" },
                { glyph: "\uf130", label: "Микрофон" }
            ];
        }
        if (key === "privacy") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf132", label: "Щит" },
                { glyph: "\uf130", label: "Микрофон" },
                { glyph: "\uf030", label: "Камера" },
                { glyph: "\uf041", label: "Геометка" },
                { glyph: "\uf06e", label: "Глаз" },
                { glyph: "\uf070", label: "Без глаза" }
            ];
        }
        if (key === "player") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf001", label: "Нота" },
                { glyph: "\uf025", label: "Наушники" },
                { glyph: "\uf008", label: "Плейлист" },
                { glyph: "\uf03e", label: "Обложка" }
            ];
        }
        return [{ glyph: "", label: "Авто" }];
    }

    function statusOptions(slot) {
        if (slot === "wifi") {
            return [
                { value: "auto", glyph: "\uf021", label: "Авто" },
                { value: "", glyph: "\uf070", label: "Скрыть" },
                { value: "\uf1eb", glyph: "\uf1eb", label: "" },
                { value: "\uf0ac", glyph: "\uf0ac", label: "" },
                { value: "\uf012", glyph: "\uf012", label: "" }
            ];
        }
        if (slot === "bluetooth") {
            return [
                { value: "auto", glyph: "\uf021", label: "Авто" },
                { value: "", glyph: "\uf070", label: "Скрыть" },
                { value: "\uf293", glyph: "\uf293", label: "" },
                { value: "\uf294", glyph: "\uf294", label: "" }
            ];
        }
        return [
            { value: "auto", glyph: "\uf021", label: "Авто" },
            { value: "", glyph: "\uf070", label: "Скрыть" },
            { value: "\uf028", glyph: "\uf028", label: "" },
            { value: "\uf026", glyph: "\uf026", label: "" },
            { value: "\uf130", glyph: "\uf130", label: "" }
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
                text: "Иконка: " + root.titleFor(root.key)
                color: Theme.scheme.onSurface
                font: Theme.typeTitleLarge
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.key === "status"
                      ? "Настройте входящие значки. Если скрыть все три, кнопка станет шестерёнкой."
                      : "«Авто» возвращает штатный вид элемента."
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
                        title: "Звук"
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
                text: "Сбросить"
                variant: "outlined"
                onClicked: root.resetIcon()
            }

            SettingsButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Готово"
                variant: "filled"
                onClicked: root.close()
            }
        }
    }
}
