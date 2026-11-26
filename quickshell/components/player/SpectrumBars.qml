import QtQuick
import "../../singletons"

// Вертикальные полосы спектра. bands — уровни 0..1 от SpectrumService;
// bars — сколько полос показать (для иконки 5, для окна 24).
Item {
    id: root

    property var bands: []
    property int bars: 5
    property real gap: 1.5
    property real minBarHeight: 2
    property color barColor: Theme.primary

    function valueAt(index) {
        if (!root.bands || root.bands.length === 0)
            return 0;
        const start = Math.floor(index * root.bands.length / root.bars);
        const end = Math.max(start + 1,
                             Math.floor((index + 1) * root.bands.length / root.bars));
        let value = 0;
        for (let i = start; i < end && i < root.bands.length; ++i)
            value = Math.max(value, Number(root.bands[i]) || 0);
        return value;
    }

    readonly property real barWidth: Math.max(1, (width - gap * (bars - 1)) / bars)

    Repeater {
        model: root.bars

        delegate: Rectangle {
            required property int index

            width: root.barWidth
            height: Math.max(root.minBarHeight, root.height * root.valueAt(index))
            x: index * (root.barWidth + root.gap)
            y: root.height - height
            radius: width / 2
            color: root.barColor
            antialiasing: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.motionShort2
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
