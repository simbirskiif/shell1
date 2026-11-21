import QtQuick
import "quick"
import "expressive"
import "../singletons"

// Индикатор громкости и яркости в духе Material 3 Expressive: не тонкая
// M3-полоска, а крупная карточка-пилюля. Слева — иконка в морфящейся форме
// (cookie/clover на primary/tertiary-контейнере), справа — крупный процент,
// снизу — волнистый PanelSlider. Оболочка (окно, выезд, позиция) — в
// OsdPopup, здесь только содержимое.
OsdPopup {
    id: root

    shown: Osd.shown
    cardWidth: 540
    // Крупная пилюля: орб 48 + крупный процент, снизу волнистая дорожка.
    cardHeight: 96

    // Значение, которое догоняет Osd.value: и волна, и процент едут
    // пружиной, а не прыгают.
    property real displayValue: 0
    Behavior on displayValue { SpringSpatial {} }

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

    // --- визуальные роли -----------------------------------------------------
    readonly property bool brightnessKind: Osd.kind === "brightness"
    // Яркость — tertiary (второй акцент панели), звук — primary.
    readonly property color accent: root.brightnessKind ? Theme.tertiary : Theme.primary
    readonly property color orbColor: Osd.muted ? Theme.surfaceContainerHighest
                                      : root.brightnessKind ? Theme.tertiaryContainer
                                      : Theme.primaryContainer
    readonly property color orbInk: Osd.muted ? Theme.scheme.onSurfaceVariant
                                   : root.brightnessKind ? Theme.scheme.onTertiaryContainer
                                   : Theme.scheme.onPrimaryContainer
    readonly property string kindIcon: Osd.muted ? "\uf026"
        : Osd.kind === "input" ? "\uf130"
        : root.brightnessKind ? "\uf185"
        : "\uf028"
    // Форма иконки-орба: громкость/яркость — «печенье», микрофон — клевер.
    readonly property string orbShape: Osd.kind === "input" ? "clover" : "cookie"

    // Строка подписи: иконка-орб 48, название источника emphasized,
    // крупный процент справа.
    Item {
        id: headerRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 6
        height: 48

        Item {
            id: orb

            width: 48
            height: 48
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            MorphShape {
                anchors.fill: parent
                shape: root.orbShape
                color: root.orbColor
                modulation: 0.9
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            Text {
                anchors.centerIn: parent
                text: root.kindIcon
                color: root.orbInk
                font.family: Theme.iconFontFamily
                font.pixelSize: 24
            }
        }

        Text {
            id: percent

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            horizontalAlignment: Text.AlignRight
            // Крупное число — акцент Expressive: читается боковым зрением.
            text: Osd.muted ? "Выкл." : Math.round(root.displayValue * 100) + "%"
            color: Osd.muted ? Theme.scheme.onSurfaceVariant : root.accent
            font: Osd.muted ? Theme.typeEmphasizedTitleMedium : Theme.typeEmphasizedTitleLarge
        }

        // Имя источника по центру: «Speaker», «Digital Microphone», «eDP-1».
        Text {
            anchors.left: orb.right
            anchors.leftMargin: Theme.space.md
            anchors.right: percent.left
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.title
            elide: Text.ElideRight
            color: Osd.muted ? Theme.scheme.onSurfaceVariant : Theme.scheme.onSurface
            font: Theme.typeEmphasizedTitleMedium
        }
    }

    // Волнистая дорожка PanelSlider — та же, что в панели яркости. Это
    // индикатор, а не контрол: ввод отключён, значение ведёт Osd.
    PanelSlider {
        id: slider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.bottomMargin: 6
        height: 36
        value: root.displayValue
        accent: root.accent
        enabled: false
    }
}
