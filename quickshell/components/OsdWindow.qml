import QtQuick
import "../singletons"

// Индикатор громкости и яркости — компактная M3-поверхность: иконка 24 слева,
// название источника по центру, процент справа, снизу — дорожка уровня с
// ручкой, как у слайдера M3. Оболочка (окно, выезд, позиция) — в OsdPopup,
// здесь только содержимое.
OsdPopup {
    id: root

    shown: Osd.shown
    cardWidth: 520
    // Компактно: строка подписи (24) + дорожка слайдера с ручкой (24) и поля.
    // Высота выросла с 44 только затем, чтобы ручка слайдера не обрезалась
    // формой карточки.
    cardHeight: 60

    // Значение, которое догоняет Osd.value: и полоска, и процент едут
    // анимацией, а не прыгают.
    property real displayValue: 0
    Behavior on displayValue {
        MotionNumber {
            duration: Theme.motionMedium1
            curve: Theme.curveStandard
        }
    }

    Connections {
        target: Osd

        function onValueChanged() {
            root.displayValue = Osd.muted ? 0 : Osd.value;
        }

        function onMutedChanged() {
            root.displayValue = Osd.muted ? 0 : Osd.value;
        }
    }

    Component.onCompleted: root.displayValue = Osd.muted ? 0 : Osd.value

    // Строка подписи: иконка 24, название источника labelLarge и процент.
    Item {
        id: headerRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.space.lg
        anchors.rightMargin: Theme.space.lg
        anchors.topMargin: Theme.space.xs
        height: Theme.iconSize.lg

        Text {
            id: icon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.muted ? "\uf026"
                : Osd.kind === "input" ? "\uf130"
                : Osd.kind === "brightness" ? "\uf185"
                : "\uf028"
            // Активный источник — primary, выключенный — вторичный тон.
            color: Osd.muted ? Theme.scheme.onSurfaceVariant : Theme.primary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.lg
        }

        Text {
            id: percent

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: Osd.muted ? "Выкл." : Math.round(root.displayValue * 100) + "%"
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelLarge
        }

        // Имя источника по центру: «Speaker», «Digital Microphone», «eDP-1».
        Text {
            anchors.left: icon.right
            anchors.leftMargin: Theme.space.md
            anchors.right: percent.left
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Osd.title
            elide: Text.ElideRight
            color: Theme.scheme.onSurface
            font: Theme.typeLabelLarge
        }
    }

    // Уровень — M3-слайдер без управления: дорожка 4, ручка 4×24 по значению.
    Item {
        id: slider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.space.lg
        anchors.rightMargin: Theme.space.lg
        anchors.bottomMargin: Theme.space.sm
        height: Theme.iconSize.lg

        // Неактивная дорожка.
        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: height / 2
            color: Theme.surfaceContainerHighest
        }

        // Активная часть — от начала до ручки.
        Rectangle {
            width: Math.max(track.height, track.width * root.displayValue)
            height: track.height
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.primary
        }

        // Конечная отметка M3 у правого края дорожки.
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 4
            radius: width / 2
            color: Theme.outline
        }

        // Ручка: вертикальная пилюля, как в M3.
        Rectangle {
            width: 4
            height: Theme.iconSize.lg
            radius: width / 2
            x: track.width * root.displayValue - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.primary
        }
    }
}
