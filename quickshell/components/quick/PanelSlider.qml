import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Слайдер Material 3 Expressive: волнистая дорожка и крупная толстая
// ручка-пилюля. Волна не украшение: по ней видно, что значение живое,
// а ручка «прыгает» на пружине и растягивается при нажатии.
Item {
    id: root

    required property real value
    // Акцент слайдера: громкость — primary, яркость — tertiary.
    property color accent: Theme.primary

    signal moved(real v)

    implicitHeight: 48

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property real trackWidth: width
    readonly property real handleX: Math.max(0, Math.min(root.trackWidth, root.trackWidth * root.value))
    readonly property real waveAmplitude: 3.2
    readonly property real wavelength: 26
    readonly property real trackThickness: 12
    readonly property real handleWidth: root.pressed ? 18 : (root.hovered ? 15 : 12)
    readonly property real handleHeight: root.pressed ? 40 : (root.hovered ? 38 : 34)

    onHandleXChanged: canvas.requestPaint()
    onValueChanged: canvas.requestPaint()
    onAccentChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const mid = height / 2;
            const amp = root.waveAmplitude;
            const len = root.wavelength;
            const x0 = 8;
            const x1 = Math.max(x0 + 1, width - 8);

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.lineWidth = root.trackThickness;

            const wave = function (from, to, color) {
                if (to <= from)
                    return;
                ctx.strokeStyle = color;
                ctx.beginPath();
                for (let x = from; x <= to; x += 3) {
                    const y = mid + amp * Math.sin((x - x0) / len * Math.PI * 2);
                    if (x === from)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            };

            // Неактивная волна — тональная, активная — акцентная.
            wave(x0, x1, Theme.surfaceContainerHighest);
            wave(x0, root.handleX, root.accent);

            // Отметка конца: маленькая точка-«стоп».
            ctx.fillStyle = Theme.outline;
            ctx.beginPath();
            ctx.arc(x1, mid, 2.5, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // Ручка: толстая пилюля с точкой внутри; при нажатии тянется.
    Rectangle {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        width: root.handleWidth
        height: root.handleHeight
        radius: width / 2
        x: root.handleX - width / 2
        color: root.accent
        border.width: 2
        border.color: Theme.withAlpha(Theme.scheme.onPrimary, 0.55)

        Behavior on width { SpringSpatial {} }
        Behavior on height { SpringSpatial {} }
        Behavior on x { SpringSpatial {} }

        Rectangle {
            anchors.centerIn: parent
            width: 4
            height: 4
            radius: 2
            color: Theme.scheme.onPrimary
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: event => root.apply(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.apply(event.x);
        }
    }

    function apply(x) {
        root.moved(Math.max(0, Math.min(1, (x - 8) / Math.max(1, root.trackWidth - 16))));
    }
}
