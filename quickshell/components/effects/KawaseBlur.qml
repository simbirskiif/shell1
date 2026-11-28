import QtQuick

// Dual Kawase blur в духе Android 16/17 (RenderEngine
// KawaseBlurDualFilterV2): цепочка уменьшений в 4, 8, 16 и 32 раза,
// затем обратный апсемплинг с 8 сэмплами по семиугольнику и смешиванием
// с более тонким уровнем. Поверх — тонировка, сатурация и маска формы.
//
// Источник обязан быть texture provider'ом: Image, ShaderEffectSource или
// item с layer.enabled. Чужие окна этот шейдер не видит — для backdrop-
// блюра панелей используется BackgroundEffect (ext-background-effect-v1).
//
// Радиус задаётся как у гауссова блюра в пикселях результата: внутри он
// пересчитывается в offset проходов по формуле Android, поэтому число
// проходов и «ширина» размытия растут согласованно.
//
// Параметры уровней выбираются автоматически (2–4), как filterPasses в
// KawaseBlurDualFilterV2. Обычно 3–4 уровня хватает на радиус 20–120 px.
Item {
    id: root

    // Item-источник: Image или ShaderEffectSource (texture provider).
    property Item sourceItem: null
    // Живое обновление цепочки. Статичный источник можно один раз
    // отрисовать и не пересчитывать каждый кадр.
    property bool live: true
    // Радиус в пикселях результата (как у гауссова блюра).
    property real blurRadius: 24
    // 0 — автоматически (2–4 уровня), иначе 2–4.
    property int levels: 0
    // Тонировка в цвет темы поверх размытия. Без неё блюр грязный,
    // а мелкий текст теряет контраст.
    property color tint: "transparent"
    property real tintOpacity: 0
    // Лёгкая сатурация: усреднение цвета «съедает» насыщенность.
    property real saturation: 1.05
    // Прибавка яркости (–1..1), если тонировка слишком тёмная.
    property real brightness: 0
    // Скругление маски результата; 0 — прямоугольник.
    property real cornerRadius: 0

    readonly property bool ready: root.sourceItem !== null
                                && root.sourceWidth > 0 && root.sourceHeight > 0

    readonly property int sourceWidth: root.sourceItem
                                       ? Math.max(1, Math.round(root.sourceItem.width))
                                       : 0
    readonly property int sourceHeight: root.sourceItem
                                        ? Math.max(1, Math.round(root.sourceItem.height))
                                        : 0

    // Радиус как у Skia: Android умножает blurRadius на 1/sqrt(3).
    readonly property real gaussianRadius: Math.max(0, root.blurRadius * 0.57735)
    // filterDepth в долях уровня 1/4 — та же формула, что в Android.
    readonly property real depth: Math.max(0, root.gaussianRadius * 0.25 / 2.5)
    readonly property int levelCount: root.levels > 0
                                      ? Math.max(2, Math.min(4, root.levels))
                                      : Math.max(2, Math.min(4, Math.ceil(root.depth) + 1))
    readonly property int passes: root.levelCount - 1

    // Размеры уровней: L0 — 1/4, L1 — 1/8, L2 — 1/16, L3 — 1/32.
    readonly property int w0: Math.max(1, Math.round(root.sourceWidth / 4))
    readonly property int h0: Math.max(1, Math.round(root.sourceHeight / 4))
    readonly property int w1: Math.max(1, Math.round(root.w0 / 2))
    readonly property int h1: Math.max(1, Math.round(root.h0 / 2))
    readonly property int w2: Math.max(1, Math.round(root.w1 / 2))
    readonly property int h2: Math.max(1, Math.round(root.h1 / 2))
    readonly property int w3: Math.max(1, Math.round(root.w2 / 2))
    readonly property int h3: Math.max(1, Math.round(root.h2 / 2))

    // Offset апсемплинга: решение Android-формулы
    // step = sqrt((radius*scale)^2 - sum(r_i^2)) / sum(step_i^2).
    function computeStep(): real {
        const depth = root.depth;
        const passes = root.passes;
        let sumR = 0;
        let sumStep = 0;
        for (let i = 0; i < passes; ++i) {
            const a = Math.min(1, depth - i);
            const r = Math.pow(2, i - 1) * a * Math.SQRT2;
            const s = Math.pow(2, i) * a;
            sumR += r * r;
            sumStep += s * s;
        }
        const target = root.gaussianRadius * 0.25;
        return Math.sqrt(Math.max(0, target * target - sumR)
                         / (sumStep === 0 ? 1 : sumStep));
    }

    function crossFade(index: int): real {
        return Math.max(0, Math.min(1, root.depth - index));
    }

    readonly property real step: root.computeStep()

    // Первый проход читает источник и сразу пишет в 1/4 разрешения.
    ShaderEffect {
        id: down0

        width: root.w0
        height: root.h0
        visible: false

        property variant source: root.ready ? root.sourceItem : null
        property vector2d texel: Qt.vector2d(1.0 / Math.max(1, root.sourceWidth),
                                             1.0 / Math.max(1, root.sourceHeight))

        fragmentShader: root.ready
                        ? Qt.resolvedUrl("kawase-down-quarter.frag.qsb") : ""
        blending: false
    }

    ShaderEffectSource {
        id: level0
        sourceItem: down0
        visible: false
        live: root.live
        smooth: true
    }

    ShaderEffect {
        id: down1

        width: root.w1
        height: root.h1
        visible: false

        property variant source: level0
        property vector2d texel: Qt.vector2d(1.0 / root.w0, 1.0 / root.h0)

        fragmentShader: root.ready
                        ? Qt.resolvedUrl("kawase-down-half.frag.qsb") : ""
        blending: false
    }

    ShaderEffectSource {
        id: level1
        sourceItem: down1
        visible: false
        live: root.live
        smooth: true
    }

    ShaderEffect {
        id: down2

        width: root.w2
        height: root.h2
        visible: false

        property variant source: level1
        property vector2d texel: Qt.vector2d(1.0 / root.w1, 1.0 / root.h1)

        fragmentShader: root.ready
                        ? Qt.resolvedUrl("kawase-down-half.frag.qsb") : ""
        blending: false
    }

    ShaderEffectSource {
        id: level2
        sourceItem: down2
        visible: false
        live: root.live
        smooth: true
    }

    ShaderEffect {
        id: down3

        width: root.w3
        height: root.h3
        visible: false

        property variant source: level2
        property vector2d texel: Qt.vector2d(1.0 / root.w2, 1.0 / root.h2)

        fragmentShader: root.ready && root.levelCount >= 4
                        ? Qt.resolvedUrl("kawase-down-half.frag.qsb") : ""
        blending: false
    }

    ShaderEffectSource {
        id: level3
        sourceItem: down3
        visible: false
        live: root.live
        smooth: true
    }

    // Апсемплинг: L3 → L2 → L1 → L0, на каждом шаге — 8 сэмплов по
    // грубому уровню и смешивание с тонким по crossFade.
    ShaderEffect {
        id: up2

        width: root.w2
        height: root.h2
        visible: false

        property variant fine: level2
        property variant coarse: level3
        property vector2d texel: Qt.vector2d(1.0 / root.w2, 1.0 / root.h2)
        property real blurOffset: root.step
        property real crossFade: root.crossFade(2)

        fragmentShader: root.ready && root.levelCount >= 4
                        ? Qt.resolvedUrl("kawase-up.frag.qsb") : ""
        blending: false
    }

    ShaderEffectSource {
        id: up2Sample
        sourceItem: up2
        visible: false
        live: root.live
        smooth: true
    }

    ShaderEffect {
        id: up1

        width: root.w1
        height: root.h1
        visible: false

        property variant fine: level1
        property variant coarse: root.levelCount >= 4 ? up2Sample : level2
        property vector2d texel: Qt.vector2d(1.0 / root.w1, 1.0 / root.h1)
        property real blurOffset: root.step
        property real crossFade: root.crossFade(1)

        fragmentShader: root.ready
                        ? Qt.resolvedUrl("kawase-up.frag.qsb") : ""
        blending: false
    }

    ShaderEffectSource {
        id: up1Sample
        sourceItem: up1
        visible: false
        live: root.live
        smooth: true
    }

    ShaderEffect {
        id: up0

        width: root.w0
        height: root.h0
        visible: false

        property variant fine: level0
        property variant coarse: root.levelCount >= 3 ? up1Sample : level1
        property vector2d texel: Qt.vector2d(1.0 / root.w0, 1.0 / root.h0)
        property real blurOffset: root.step
        property real crossFade: root.crossFade(0)

        fragmentShader: root.ready
                        ? Qt.resolvedUrl("kawase-up.frag.qsb") : ""
        blending: false
    }

    ShaderEffectSource {
        id: up0Sample
        sourceItem: up0
        visible: false
        live: root.live
        smooth: true
    }

    // Финальный проход в полном разрешении: тонировка, сатурация и маска.
    ShaderEffect {
        anchors.fill: parent
        visible: root.ready

        property variant source: up0Sample
        property vector2d size: Qt.vector2d(Math.max(1, root.width),
                                            Math.max(1, root.height))
        property real radius: root.cornerRadius
        property color tint: root.tint
        property real tintOpacity: root.tintOpacity
        property real saturation: root.saturation
        property real brightness: root.brightness

        fragmentShader: Qt.resolvedUrl("kawase-composite.frag.qsb")
    }
}
