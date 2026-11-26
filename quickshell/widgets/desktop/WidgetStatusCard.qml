import QtQuick
import "../../singletons"
import "../core"

// Карточка состояния вместо контента виджета: ошибка загрузки QML или
// «виджет недоступен». Ужимается до размера маленькой клетки: в компактном
// режиме остаются иконка, имя и кнопки-символы.
//
// Оформление — M3 card: tonal surface high, радиус md (у крупной — lg),
// без тени; обводка — outline-variant. Выбранное/активное состояние тут не
// нужно: карточка сама сообщает об ошибке цветом error.
Item {
    id: root

    property string icon: "⚠"
    property string title: ""
    property string message: ""
    property bool showReload: true

    signal reloadRequested()
    signal deleteRequested()

    readonly property bool compact: width < 120 || height < 110
    readonly property int cardRadius: root.compact ? Theme.shape.md : Theme.shape.lg
    readonly property int cardPadding: root.compact ? Theme.space.sm : Theme.space.lg

    // Подложка — M3 card. Тень не нужна: глубину задаёт тон поверхности.
    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outlineVariant
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - root.cardPadding * 2,
                        root.compact ? parent.width - Theme.space.sm * 2 : 260)
        spacing: root.compact ? Theme.space.xs : Theme.space.sm

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.error
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? Theme.typescale.titleMedium.size
                                         : Theme.typescale.headlineSmall.size
            text: root.icon
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.scheme.onSurface
            font: root.compact ? Theme.typeTitleSmall : Theme.typeTitleMedium
            elide: Text.ElideRight
            text: root.title
        }

        Text {
            width: parent.width
            visible: !root.compact && root.message.length > 0
            horizontalAlignment: Text.AlignHCenter
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: root.message
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.space.xs

            HostButton {
                text: root.compact ? "↻" : I18n.tr("widgets.reload")
                visible: root.showReload
                onClicked: root.reloadRequested()
            }

            HostButton {
                text: root.compact ? "✕" : I18n.tr("common.delete")
                onClicked: root.deleteRequested()
            }
        }
    }
}
