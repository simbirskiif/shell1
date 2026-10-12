import QtQuick
import ".."
import "../../singletons"

// Индикатор Wi-Fi: дуга с тремя делениями.
//   * включён и подключён — горят деления по уровню сигнала (1–3);
//   * включён, но не подключён — все деления серые;
//   * выключен — значок приглушён и перечёркнут.
//
// Глифов делений в Nerd Font нет (в шрифте есть только общий значок Wi-Fi),
// поэтому рисуем сами, как индикатор загрузки: дуги Canvas.
Item {
    id: root

    property bool wifiEnabled: true
    property bool connected: false
    // Уровень сигнала 0–3: сколько делений горит.
    property int signal: 0

    // Слот для иконки в кружке плитки: заливка кружка — accent, поэтому
    // значок на нём рисуем цветом фона.
    property bool onAccent: false

    implicitWidth: 18
    implicitHeight: 18

    readonly property int level: Math.max(0, Math.min(3, signal))

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        Connections {
            target: root

            function onWifiEnabledChanged() { canvas.requestPaint(); }
            function onConnectedChanged() { canvas.requestPaint(); }
            function onSignalChanged() { canvas.requestPaint(); }
            function onOnAccentChanged() { canvas.requestPaint(); }
            function onWidthChanged() { canvas.requestPaint(); }
            function onHeightChanged() { canvas.requestPaint(); }
        }

        Connections {
            target: Theme

            function onAccentChanged() { canvas.requestPaint(); }
            function onQuickTextChanged() { canvas.requestPaint(); }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const w = width;
            const h = height;
            const cx = w / 2;
            const stroke = Math.max(1.8, w * 0.115);

            // Геометрия в долях размера (проверена для 18 px):
            //   top = 0.66h    — центр дуг
            //   r1..r3         — радиусы внутренней, средней и внешней дуг
            //   dotY = 0.82h   — точка-основание
            // Верх внешней дуги получается на 0.08h от края: сглаживание не
            // упирается в границу холста, поэтому верх не срезается.
            const top = h * 0.66;
            const r1 = w * 0.14;
            const r2 = w * 0.28;
            const r3 = w * 0.42;
            const dotRadius = Math.max(1.3, stroke * 0.7);
            const dotY = h * 0.82;

            // На кружке плитки фон — accent (оранжевый), поэтому:
            //   * активные дуги — цветом фона (тёмные, читаются на оранжевом);
            //   * неактивные — светлые, иначе они сливались бы с кружком.
            const mainColor = root.onAccent ? String(Theme.quickIconOn)
                                            : String(Theme.quickText);
            const dimColor = root.onAccent ? String(Theme.menuSurface)
                                           : String(Theme.quickTextDim);
            const onColor = root.connected ? mainColor : dimColor;

            // Три дуги: у каждой свой цвет и прозрачность — так состояние
            // читается и в 18 пикселей.
            const radii = [r1, r2, r3];
            const lit = root.wifiEnabled ? root.level : 0;

            ctx.lineCap = "round";
            for (let i = 0; i < radii.length; ++i) {
                const isOn = root.wifiEnabled && i < lit;
                ctx.strokeStyle = isOn ? onColor : dimColor;
                ctx.globalAlpha = isOn ? 1.0 : (root.wifiEnabled ? 0.9 : 0.45);
                ctx.lineWidth = stroke;
                ctx.beginPath();
                ctx.arc(cx, top, radii[i], Math.PI * 1.25, Math.PI * 1.75);
                ctx.stroke();
            }

            // Точка-основание.
            ctx.globalAlpha = root.wifiEnabled ? 1.0 : 0.45;
            ctx.fillStyle = (root.wifiEnabled && root.connected) ? onColor : dimColor;
            ctx.beginPath();
            ctx.arc(cx, dotY, dotRadius, 0, Math.PI * 2);
            ctx.fill();

            // Выключен — перечёркиваем.
            if (!root.wifiEnabled) {
                ctx.globalAlpha = 0.9;
                ctx.strokeStyle = String(Theme.lowColor);
                ctx.lineWidth = Math.max(1.6, w * 0.11);
                ctx.beginPath();
                ctx.moveTo(w * 0.22, h * 0.18);
                ctx.lineTo(w * 0.78, h * 0.82);
                ctx.stroke();
            }
        }
    }
}
