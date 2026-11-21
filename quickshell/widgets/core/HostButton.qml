import QtQuick
import "../../components/expressive"
import "../../singletons"

// Маленькая кнопка для карточек, каталога и попапа настроек.
// Material 3 Expressive: состояние читается формой, а не только цветом.
//   prominent — залитая primary-«пилюля» с пружинным откликом;
//   active    — заметный tertiary-контейнер;
//   обычная   — тональная поверхность над обоями.
// При наведении кнопка надувается и перетекает в пилюлю, при нажатии —
// сжимается в squircle. Всё движение — пружины, без длительностей.
Item {
    id: root

    property string text: ""
    property bool active: false
    property bool prominent: false
    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    implicitWidth: label.implicitWidth + (root.prominent ? Theme.space.xxl
                                       : (root.text.length > 1 ? Theme.space.xxl
                                                               : Theme.space.md))
    implicitHeight: root.prominent ? 40 : 32

    // Формы соседствуют контрастно: squircle в покое, пилюля на hover,
    // активная — «печенье», нажатие стягивает в squircle.
    readonly property string shapeName:
        root.pressed ? "squircle"
        : root.active ? "cookie"
        : root.hovered ? "pill"
        : "squircle"

    scale: root.pressed ? 0.92 : (root.hovered ? 1.06 : 1)
    Behavior on scale { SpringSpatial {} }
    Behavior on implicitHeight { SpringSpatial {} }
    Behavior on implicitWidth { SpringSpatial {} }

    MorphShape {
        anchors.fill: parent
        shape: root.shapeName
        // Кнопка узкая и маленькая: амплитуду контура приглушаем, чтобы
        // «печенье» не превращалось в кляксу в строке таблицы.
        modulation: 0.55
        color: root.prominent
               ? (root.hovered
                  ? Theme.mix(Theme.primary, Theme.scheme.onPrimary, Theme.stateHover)
                  : Theme.primary)
               : root.active
                 ? (root.hovered
                    ? Theme.mix(Theme.tertiaryContainer, Theme.scheme.onTertiaryContainer,
                                Theme.stateHover)
                    : Theme.tertiaryContainer)
                 : (root.hovered ? Theme.secondaryContainer : Theme.surfaceContainerHigh)
        // Тонких обводок нет: неактивная кнопка — тональный контейнер,
        // состояние читается цветом и формой, как в Expressive.
        borderWidth: 0
        borderColor: Theme.outlineVariant
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: label

        anchors.centerIn: parent
        color: root.prominent
               ? Theme.scheme.onPrimary
               : root.active
                 ? Theme.scheme.onTertiaryContainer
                 : root.hovered ? Theme.scheme.onSecondaryContainer
                                : Theme.scheme.onSurface
        font: root.prominent || root.active ? Theme.typeEmphasizedLabelLarge
                                            : Theme.typeLabelLarge
        text: root.text
        scale: root.pressed ? 0.96 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { SpringSpatialFast {} }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
