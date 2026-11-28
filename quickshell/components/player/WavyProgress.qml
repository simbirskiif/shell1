import QtQuick
import "../expressive"
import "../../singletons"

// Expressive-прогресс: пройденная часть — волна primary, оставшаяся —
// ровная линия, ручка — вертикальная пилюля. Амплитуда волны на паузе
// гасится, движение значения — на пружине.
Item {
    id: root

    required property real value
    property bool playing: false
    property bool enabled: true
    property color activeColor: Theme.primary
    property color trackColor: Theme.surfaceVariant
    signal moved(real value)

    implicitHeight: 44

    property bool dragging: false
    property real shownValue: root.value
    property real amplitude: root.playing ? 2.4 : 0.55

    Behavior on shownValue {
        enabled: !root.dragging
        SpringSpatialFast {}
    }
    Behavior on amplitude { SpringSpatialFast {} }

    onValueChanged: {
        if (!root.dragging)
            root.shownValue = root.value;
    }
    onShownValueChanged: wave.requestPaint()
    onAmplitudeChanged: wave.requestPaint()

    // Неактивная часть: ровная линия.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 3
        radius: height / 2
        color: root.trackColor
    }

    // Активная часть: волна, обрезанная по текущему значению. Canvas
    // перерисовывается только при изменении значения/амплитуды.
    Canvas {
        id: wave

        width: Math.max(0, Math.min(root.width, root.width * root.shownValue))
        height: root.height
        visible: width > 1

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            ctx.clearRect(0, 0, w, h);
            if (w <= 0)
                return;
            ctx.beginPath();
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.strokeStyle = root.activeColor;
            for (let x = 1.5; x <= w; x += 2) {
                const y = h / 2 + Math.sin(x / 13.0) * root.amplitude;
                if (x <= 1.5)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    }

    // Ручка: вертикальная пилюля с ореолом состояния.
    Rectangle {
        width: root.dragging || mouse.containsMouse ? 6 : 4
        height: root.dragging || mouse.containsMouse ? 28 : 22
        radius: width / 2
        x: Math.max(0, Math.min(root.width - width, root.width * root.shownValue - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: root.enabled ? root.activeColor : Theme.quickTextDim
        Behavior on width { SpringSpatialFast {} }
        Behavior on height { SpringSpatialFast {} }
        Behavior on x { SpringSpatialFast {} }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: event => {
            root.dragging = true;
            root.apply(event.x);
        }
        onPositionChanged: event => {
            if (pressed)
                root.apply(event.x);
        }
        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }

    function apply(x) {
        const value = Math.max(0, Math.min(1, x / Math.max(1, width)));
        root.shownValue = value;
        root.moved(value);
    }
}
