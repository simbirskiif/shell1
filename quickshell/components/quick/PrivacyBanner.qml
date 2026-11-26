import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Строка конфиденциальности в быстрых настройках: те же цветные орбы, что
// и в баре, плюс постоянный вход в историю. Когда ничего не используется,
// показывает нейтральный щит. Высота едет на пружине, поэтому сетка плиток
// сдвигается плавно, а не прыжком.
Item {
    id: root

    property bool shown: false

    signal opened()

    implicitHeight: root.shown ? 64 : 0
    height: implicitHeight
    // Во время раскрытия/схлопывания контент обрезается, чтобы не выезжал
    // за строку.
    visible: height > 0.5
    clip: true
    Behavior on implicitHeight { SpringSpatial {} }

    opacity: root.shown ? 1 : 0
    Behavior on opacity { SpringEffects {} }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Theme.quickTileRadius
        color: hover.containsMouse ? Theme.quickTileHover : Theme.quickTile
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    PrivacyIndicator {
        id: orbs

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        // В покое — нейтральный щит, при использовании — цветные орбы.
        previewMode: !PrivacyService.anyActive
        // Кликается вся строка целиком.
        interactive: false
    }

    Column {
        anchors.left: orbs.right
        anchors.leftMargin: Theme.space.md
        anchors.right: chevron.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            width: parent.width
            text: I18n.tr("quick.tile.privacy")
            color: Theme.scheme.onSurface
            font: Theme.typeLabelLarge
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: PrivacyService.anyActive
                  ? PrivacyService.activeSummary : I18n.tr("quick.privacy.noActive")
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelMedium
            elide: Text.ElideRight
        }
    }

    Text {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf054"
        color: Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }
}
