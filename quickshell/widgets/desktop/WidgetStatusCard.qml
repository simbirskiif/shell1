import QtQuick
import "../../components/expressive"
import "../../singletons"
import "../core"

// Карточка состояния вместо контента виджета: ошибка загрузки QML или
// «виджет недоступен». Ужимается до размера маленькой клетки: в компактном
// режиме остаются иконка, имя и кнопки-символы.
//
// Оформление — Expressive: проблемная карточка целиком в error-контейнере
// (форма «печенье», в компактном размере — спокойный squircle), заголовок
// typeEmphasized*, иконка крупнее текста, кнопки — HostButton-пилюли.
Item {
    id: root

    property string icon: "⚠"
    property string title: ""
    property string message: ""
    property bool showReload: true

    signal reloadRequested()
    signal deleteRequested()

    readonly property bool compact: width < 120 || height < 110
    readonly property int cardRadius: root.compact ? Theme.shape.lg : Theme.shape.xl
    readonly property int cardPadding: root.compact ? Theme.space.sm : Theme.space.lg

    // Компактная карточка — спокойный squircle; крупная — «печенье»,
    // чтобы проблему было видно боковым зрением.
    MorphShape {
        anchors.fill: parent
        shape: root.compact ? "squircle" : "cookie"
        modulation: 0.42
        color: Theme.errorContainer
        borderWidth: 0
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - root.cardPadding * 2,
                        root.compact ? parent.width - Theme.space.sm * 2 : 260)
        spacing: root.compact ? Theme.space.xs : Theme.space.sm

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.scheme.onErrorContainer
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? Theme.typescale.titleMedium.size
                                         : Theme.typescale.headlineMedium.size
            text: root.icon
            scale: root.compact ? 0.9 : 1
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.scheme.onErrorContainer
            font: root.compact ? Theme.typeEmphasizedLabelLarge
                               : Theme.typeEmphasizedTitleMedium
            elide: Text.ElideRight
            text: root.title
        }

        Text {
            width: parent.width
            visible: !root.compact && root.message.length > 0
            horizontalAlignment: Text.AlignHCenter
            color: Theme.withAlpha(Theme.scheme.onErrorContainer, 0.78)
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
                text: root.compact ? "↻" : "Перезагрузить"
                prominent: true
                visible: root.showReload
                onClicked: root.reloadRequested()
            }

            HostButton {
                text: root.compact ? "✕" : "Удалить"
                onClicked: root.deleteRequested()
            }
        }
    }
}
