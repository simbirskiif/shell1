import QtQuick
import "."
import "../../singletons"

// Button group Material 3 Expressive: кнопки склеены в одну пилюлю.
// Активный сегмент шире остальных, а при нажатии он раздувается, и
// соседние сегменты упруго поджимаются — группа «дышит» под пальцем.
Item {
    id: root

    required property var tabs       // [{ key, title }]
    required property string current
    property string tone: "tertiary" // цвет активного сегмента

    signal selected(string key)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 52
    height: implicitHeight

    property int pressedIndex: -1

    readonly property int activeIndex: {
        for (let i = 0; i < root.tabs.length; ++i) {
            if (root.tabs[i].key === root.current)
                return i;
        }
        return 0;
    }

    readonly property color activeContainer: root.tone === "primary" ? Theme.primaryContainer
                                           : root.tone === "secondary" ? Theme.secondaryContainer
                                           : Theme.tertiaryContainer
    readonly property color activeInk: root.tone === "primary" ? Theme.scheme.onPrimaryContainer
                                     : root.tone === "secondary" ? Theme.scheme.onSecondaryContainer
                                     : Theme.scheme.onTertiaryContainer

    function weightFor(index) {
        if (index === root.pressedIndex)
            return 1.45;
        if (index === root.activeIndex)
            return 1.25;
        return 0.9;
    }

    function segmentWidth(index) {
        const n = root.tabs.length;
        if (n === 0)
            return 0;
        let total = 0;
        for (let i = 0; i < n; ++i)
            total += root.weightFor(i);
        const gap = 4;
        const available = root.width - 8 - gap * (n - 1);
        return Math.max(0, available * root.weightFor(index) / total);
    }

    // Трек: плотная тональная пилюля, внутри — сегменты.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceContainerHigh
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.tabs

            delegate: Item {
                id: segment

                required property var modelData
                required property int index

                readonly property bool active: modelData.key === root.current
                readonly property bool pressed: root.pressedIndex === index
                readonly property bool hovered: hoverArea.containsMouse

                width: root.segmentWidth(index)
                height: root.height - 8
                Behavior on width { SpringSpatial {} }

                MorphShape {
                    anchors.fill: parent
                    shape: segment.pressed ? "squircle" : (segment.active ? "pill" : "circle")
                    color: segment.active ? root.activeContainer
                         : segment.hovered ? Theme.surfaceContainerHighest
                         : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: segment.modelData.title
                    color: segment.active ? root.activeInk : Theme.scheme.onSurfaceVariant
                    font: segment.active ? Theme.typeEmphasizedLabelLarge : Theme.typeLabelLarge
                    scale: segment.pressed ? 0.96 : 1
                    Behavior on scale { SpringSpatialFast {} }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: root.pressedIndex = segment.index
                    onReleased: root.pressedIndex = -1
                    onCanceled: root.pressedIndex = -1
                    onClicked: root.selected(segment.modelData.key)
                }
            }
        }
    }
}
