import QtQuick
import "../../singletons"

// Выразительная форма Material 3 Expressive.
//
// Контур задаётся полярным радиусом: каждая точка — r(θ), поэтому форма
// может непрерывно перетекать из одной в другую. Пресеты:
//   circle, squircle, pill, cookie (волнистый круг), sunny (лучики),
//   clover (четырёхлистник), burst (острые лучи), blob (неровное пятно).
//
// Смена shape анимируется пружиной spatial: контур «переползает» из старой
// формы в новую, с лёгким перелётом. Это и есть морфинг Expressive —
// состояние читается по форме, а не только по цвету.
Item {
    id: root

    property string shape: "cookie"
    property color color: "#00000000"
    property color borderColor: "transparent"
    property real borderWidth: 0
    // Сила выразительности: 1 — полная амплитуда контура, 0.5 — спокойнее.
    // Для широких плиток большие амплитуды растягиваются в «баннер»,
    // поэтому фон плитки приглушают, а иконка-орб остаётся смелой.
    property real modulation: 1

    // Морфинг: 0 — fromArr, 1 — toArr. Наружу менять не нужно.
    property real morph: 1
    property var fromArr: []
    property var toArr: []

    readonly property int samples: 120

    implicitWidth: 48
    implicitHeight: 48

    onShapeChanged: {
        const current = root.radii();
        root.fromArr = current;
        root.toArr = root.preset(root.shape);
        root.morph = 0;
        morphAnim.restart();
    }

    Component.onCompleted: {
        root.fromArr = root.preset(root.shape);
        root.toArr = root.fromArr;
        root.morph = 1;
        canvas.requestPaint();
        // Краска может прийтись на кадр, когда цветовые биндинги ещё не
        // разрешились: перерисовываем ещё раз после инициализации.
        Qt.callLater(canvas.requestPaint);
    }

    // Радиусы пресета, нормированные так, чтобы форма касалась краёв.
    function preset(name) {
        const n = root.samples;
        const out = new Array(n);
        for (let i = 0; i < n; ++i) {
            const a = i / n * Math.PI * 2;
            const ca = Math.cos(a);
            const sa = Math.sin(a);
            let r = 1;
            if (name === "circle") {
                r = 1;
            } else if (name === "squircle") {
                r = Math.pow(Math.pow(Math.abs(ca), 3.2) + Math.pow(Math.abs(sa), 3.2), -1 / 3.2);
            } else if (name === "pill") {
                r = Math.pow(Math.pow(Math.abs(ca), 8.0) + Math.pow(Math.abs(sa), 8.0), -1 / 8.0);
            } else if (name === "cookie") {
                // Волнистый круг: 7 мягких долек + лёгкая асимметрия.
                r = 1 + 0.075 * Math.cos(7 * a) + 0.028 * Math.cos(3 * a + 0.8);
            } else if (name === "sunny") {
                // Круг с частыми округлыми лучами.
                r = 1 + 0.16 * Math.cos(12 * a) + 0.03 * Math.cos(4 * a);
            } else if (name === "clover") {
                // Четырёхлистник: глубокие вырезы между долями.
                r = 1 + 0.26 * Math.cos(4 * a);
            } else if (name === "burst") {
                // Острые лучи: тот же принцип, но глубже и чаще.
                r = 1 + 0.34 * Math.cos(10 * a);
            } else if (name === "blob") {
                // Неровное пятно: три несоизмеримые волны.
                r = 1 + 0.085 * Math.sin(3 * a + 1.1)
                      + 0.055 * Math.sin(5 * a + 2.3)
                      + 0.03 * Math.sin(2 * a + 0.4);
            }
            out[i] = 1 + (r - 1) * root.modulation;
        }
        let max = 0;
        for (let i = 0; i < n; ++i)
            max = Math.max(max, out[i]);
        if (max > 0) {
            for (let i = 0; i < n; ++i)
                out[i] /= max;
        }
        return out;
    }

    function radii() {
        if (!root.fromArr || !root.toArr || root.fromArr.length === 0
                || root.toArr.length === 0)
            return root.preset(root.shape);
        const t = root.morph;
        const out = new Array(root.fromArr.length);
        for (let i = 0; i < out.length; ++i) {
            const a = root.fromArr[i];
            const b = root.toArr[i] !== undefined ? root.toArr[i] : a;
            out[i] = a + (b - a) * t;
        }
        return out;
    }

    onMorphChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onBorderColorChanged: canvas.requestPaint()
    onBorderWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            ctx.clearRect(0, 0, w, h);

            const inset = Math.max(1, root.borderWidth / 2 + 0.5);
            const rx = Math.max(0, w / 2 - inset);
            const ry = Math.max(0, h / 2 - inset);
            const radii = root.radii();
            const n = radii.length;

            ctx.save();
            ctx.translate(w / 2, h / 2);
            ctx.beginPath();
            for (let i = 0; i < n; ++i) {
                const a = i / n * Math.PI * 2;
                const x = Math.cos(a) * rx * radii[i];
                const y = Math.sin(a) * ry * radii[i];
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.closePath();

            if (root.color.a > 0) {
                ctx.fillStyle = root.color;
                ctx.fill();
            }
            if (root.borderWidth > 0 && root.borderColor.a > 0) {
                ctx.lineWidth = root.borderWidth;
                ctx.strokeStyle = root.borderColor;
                ctx.stroke();
            }
            ctx.restore();
        }
    }

    SpringAnimation {
        id: morphAnim
        target: root
        property: "morph"
        to: 1
        spring: Theme.springs.spatial.spring
        damping: Theme.springs.spatial.damping
        epsilon: 0.001
    }
}
