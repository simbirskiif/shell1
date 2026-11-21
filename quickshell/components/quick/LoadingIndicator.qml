import QtQuick
import ".."
import "../../singletons"

// Загрузка в Material 3 Expressive: не вращающаяся дуга, а живая
// морфящаяся клякса. Две волны разной частоты непрерывно перетекают,
// вторая клякса другого акцента дышит в противофазе.
Item {
    id: root

    implicitWidth: Theme.iconSize.lg
    implicitHeight: Theme.iconSize.lg

    // Оставлено для совместимости со старым API индикатора.
    property real sweep: 90
    property color accent: Theme.primary

    property real phase: 0

    Timer {
        interval: 16
        repeat: true
        running: root.visible
        onTriggered: root.phase += 0.055
    }

    onPhaseChanged: canvas.requestPaint()
    onAccentChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const cx = width / 2;
            const cy = height / 2;
            const base = Math.min(width, height) / 2 - 1.5;

            const blob = function (radius, phase, color, wobble) {
                const n = 48;
                ctx.beginPath();
                for (let i = 0; i <= n; ++i) {
                    const a = i / n * Math.PI * 2;
                    const r = radius * (1
                        + 0.16 * Math.sin(3 * a + phase)
                        + 0.09 * Math.sin(5 * a - phase * 1.4)
                        + wobble * 0.05 * Math.sin(7 * a + phase * 2));
                    const x = cx + Math.cos(a) * r;
                    const y = cy + Math.sin(a) * r;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.closePath();
                ctx.fillStyle = color;
                ctx.fill();
            };

            // Вторая клякса — терракотовый акцент, чуть меньше и сбоку.
            blob(base * 0.72, root.phase * 1.35 + 1.7,
                 Theme.withAlpha(Theme.tertiary, 0.85), 0.6);
            // Основная — акцентная, крупнее.
            blob(base * 0.9, root.phase, root.accent, 1.0);
        }
    }
}
