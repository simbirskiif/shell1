import QtQuick
import "../expressive"
import "../../singletons"

// Компактная полоса дока: приложения, разделитель и кнопка раскрытия.
// Кнопка может стоять справа или слева. Позиции считаем вручную, чтобы
// смена стороны не пересоздавала делегаты и не мигала иконками.
//
// Expressive: приложения собраны в крупные воздушные формы, разделитель —
// не линия в 1 px, а маленькая цветная «печенька», а раскрытие делает
// полноценный FAB (cookie → squircle при наведении), а не мелкая иконка.
Item {
    id: root

    property bool buttonFirst: false
    property real buttonSize: Theme.dockButtonSize
    property real iconSize: Theme.dockIconSize
    property real glyphSize: Theme.iconSize.sm

    // Ширина разделителя участвует в раскладке: он позиционный, а не
    // декоративная линия под иконками.
    readonly property real separatorWidth: 6

    signal expandRequested()

    implicitWidth: appsRow.implicitWidth + root.separatorWidth + root.buttonSize
                   + Theme.dockSpacing * 2
    implicitHeight: root.buttonSize

    Row {
        id: appsRow
        x: root.buttonFirst
           ? root.buttonSize + Theme.dockSpacing * 2 + root.separatorWidth
           : 0
        spacing: Theme.dockSpacing

        Repeater {
            model: DockApps.favorites

            delegate: DockAppButton {
                required property var modelData
                required property int index

                size: root.buttonSize
                iconSize: root.iconSize
                slot: index
                // Чёт/нечет чередует акценты, поэтому соседние запущенные
                // приложения выглядят как разные формы, а не как один цвет.
                accent: index % 2 === 0 ? "primary" : "tertiary"
                entry: modelData
                onActivated: DockState.hide()
            }
        }
    }

    // Разделитель-«печенька»: группирует приложения и управляющую кнопку
    // цветом и формой, без тонкой линии через всю высоту карточки.
    Item {
        id: separator
        x: root.buttonFirst ? root.buttonSize + Theme.dockSpacing
                            : appsRow.width + Theme.dockSpacing
        width: root.separatorWidth
        height: root.buttonSize

        MorphShape {
            anchors.centerIn: parent
            width: 6
            height: 6
            shape: "cookie"
            modulation: 0.9
            color: Theme.tertiary
        }
    }

    // Раскрытие панели — главное действие дока, поэтому это FAB:
    // крупная форма-«печенье» tertiary-контейнера, при наведении
    // перетекающая в squircle и упруго подрастающая.
    ExpressiveFab {
        id: expandButton
        x: root.buttonFirst ? 0
                            : appsRow.width + Theme.dockSpacing * 2 + root.separatorWidth
        size: Math.round(root.buttonSize)
        icon: "\uf077"
        tone: "tertiary"
        shape: "cookie"
        hoverShape: "squircle"

        onClicked: root.expandRequested()
    }
}
