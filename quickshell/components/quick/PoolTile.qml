import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Плитка в пуле доступных: показывает только значок, подпись проявляется
// при наведении. «Плюс» в углу выходит за пределы плитки и возвращает
// её на панель.
//
// Expressive: плитка — крупная морфящаяся форма (в покое squircle, на hover
// «печенье» secondary-контейнера), иконка — орб; «+» — маленький Expressive
// FAB, а не плоская кнопка.
Rectangle {
    id: root

    required property string icon
    required property string title

    // Управляется панелью: гасить/проявлять плитку в пуле.
    property bool shown: true

    signal addRequested()

    implicitWidth: Theme.quickWidth / 2
    implicitHeight: Theme.quickTileHeight
    // Корневой Rectangle нужен только для раскладки: фон рисует MorphShape.
    radius: Theme.quickTileRadius
    color: "transparent"

    readonly property bool hovered: hover.containsMouse

    Behavior on x { SpringSpatial {} }
    Behavior on y { SpringSpatial {} }
    Behavior on opacity { SpringEffects {} }
    Behavior on scale { SpringSpatial {} }

    // Фон-форма: состояние читается контуром, а не рамкой.
    MorphShape {
        anchors.fill: parent
        shape: root.hovered ? "cookie" : "squircle"
        color: root.hovered ? Theme.secondaryContainer : Theme.surfaceContainerHigh
        modulation: 0.5
        borderWidth: root.hovered ? 0 : 1
        borderColor: Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addRequested()
    }

    // Орб-иконка: в покое круг, на hover «солнышко» primary-контейнера.
    MorphShape {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Theme.space.xs
        width: 46
        height: 46
        shape: root.hovered ? "sunny" : "circle"
        color: root.hovered ? Theme.primaryContainer : Theme.surfaceContainerHighest
        modulation: 1

        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.hovered ? Theme.scheme.onPrimaryContainer
                                : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: 22
        }
    }

    // Подпись появляется только при наведении — в покое плитка «пустая».
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: Theme.space.xs + 2
        width: parent.width - Theme.space.md
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.title
        color: Theme.scheme.onSurface
        font: Theme.typeLabelMedium
        opacity: root.hovered ? 1 : 0
        Behavior on opacity { SpringEffects {} }
    }

    // «Плюс» — Expressive FAB: крупнее и выступает за плитку.
    ExpressiveFab {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -Theme.space.xs
        anchors.topMargin: -Theme.space.xs
        size: 40
        icon: "\uf067"
        tone: "tertiary"
        shape: "cookie"
        hoverShape: "sunny"
        onClicked: root.addRequested()
    }
}
