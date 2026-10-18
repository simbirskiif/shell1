import QtQuick

// Проба фона под карточкой виджета.
//
// Виджет не имеет доступа к композитору и не может «посмотреть» пиксели
// обоев под собой. Shell делает это сам: уменьшает нужный кусок обоев до
// сетки 16×16, считает средний цвет и относительную яркость и отдаёт
// виджету готовую рекомендацию по тексту через ctx.backdrop.
//
// Учитываются именно обои, а не содержимое карточки: проба не должна
// зависеть от текста, который сама же и окрашивает. Другие виджеты в
// обычной раскладке не перекрываются; во время drag материал отдельно
// получает их текстуру.
Item {
    id: root

    // --- Входные данные (заполняет WidgetHost) ---
    property string source: ""
    property real screenWidth: 0
    property real screenHeight: 0
    property real rectX: 0
    property real rectY: 0
    property real rectWidth: 0
    property real rectHeight: 0

    // Цвет-запасной вариант, если обои неизвестны или ещё не загрузились.
    // Host передаёт сюда surface системной палитры.
    property color fallbackColor: "#151519"

    // --- Результат ---
    property bool ready: false
    property color averageColor: root.fallbackColor
    property real luminance: root.luminanceOf(root.background)

    readonly property color background: root.ready ? root.averageColor
                                                   : root.fallbackColor
    readonly property color ink: root.bestInk(root.background)
    readonly property color inkMuted: root.mutedInk(root.ink, root.background)
    readonly property bool inkIsWhite: root.luminanceOf(root.ink) > 0.5
    readonly property color veil: root.inkIsWhite
                                   ? Qt.rgba(0, 0, 0, 0.28)
                                   : Qt.rgba(1, 1, 1, 0.30)
    readonly property real contrast: root.contrastOf(root.ink, root.background)
    readonly property bool isLight: root.luminance >= 0.179

    // Публичный объект для ctx.backdrop. Виджет не получает Canvas и
    // служебные Image, только стабильные свойства и refresh().
    readonly property QtObject info: QtObject {
        id: publicInfo

        readonly property bool ready: root.ready
        readonly property color background: root.background
        readonly property color averageColor: root.background
        readonly property real luminance: root.luminance
        readonly property bool isLight: root.isLight
        readonly property color ink: root.ink
        readonly property color inkMuted: root.inkMuted
        readonly property color veil: root.veil
        readonly property real contrast: root.contrast

        // Принудительная перепроверка, если виджет сам изменил геометрию
        // (обычно shell делает это автоматически при resize/drag).
        function refresh(): void {
            root.schedule()
        }
    }

    // --- Цветовые вычисления ---
    function linearize(v: real): real {
        return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }

    function luminanceOf(c: color): real {
        return 0.2126 * linearize(c.r) + 0.7152 * linearize(c.g)
             + 0.0722 * linearize(c.b)
    }

    function contrastOf(a: color, b: color): real {
        const la = luminanceOf(a)
        const lb = luminanceOf(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    function bestInk(bg: color): color {
        // Максимальный контраст всегда даёт либо белый, либо чёрный.
        // Порог 0.179 — точка, где эти два варианта равны (~4.58:1).
        return luminanceOf(bg) >= 0.179 ? "#000000" : "#ffffff"
    }

    function blend(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    function mutedInk(inkColor: color, bg: color): color {
        // Вторичный текст чуть смешиваем с фоном, но не ниже 4.5:1.
        // На средних фонах (где чёрный/белый и так на пределе) возвращаем
        // основной ink без ослабления.
        for (let t = 0.18; t > 0.001; t -= 0.03) {
            const candidate = blend(inkColor, bg, t)
            if (contrastOf(candidate, bg) >= 4.5)
                return candidate
        }
        return inkColor
    }

    function schedule(): void {
        if (root.source.length === 0) {
            root.ready = false
            return
        }
        debounce.restart()
    }

    function paint(): void {
        if (sampler.available)
            sampler.requestPaint()
    }

    function collectSample(): void {
        if (root.source.length === 0
            || wallpaper.status !== Image.Ready
            || root.screenWidth <= 0 || root.screenHeight <= 0
            || root.rectWidth <= 0 || root.rectHeight <= 0)
            return

        const iw = wallpaper.implicitWidth
        const ih = wallpaper.implicitHeight
        if (iw <= 0 || ih <= 0)
            return

        // Материалы рисуют обои через Image.PreserveAspectCrop. Повторяем
        // это же отображение, иначе проба возьмёт не тот участок картинки.
        const scale = Math.max(root.screenWidth / iw, root.screenHeight / ih)
        const visibleW = root.screenWidth / scale
        const visibleH = root.screenHeight / scale
        const cropX = (iw - visibleW) / 2
        const cropY = (ih - visibleH) / 2

        let x0 = cropX + root.rectX / scale
        let y0 = cropY + root.rectY / scale
        let x1 = cropX + (root.rectX + root.rectWidth) / scale
        let y1 = cropY + (root.rectY + root.rectHeight) / scale

        x0 = Math.max(0, Math.min(iw, x0))
        y0 = Math.max(0, Math.min(ih, y0))
        x1 = Math.max(0, Math.min(iw, x1))
        y1 = Math.max(0, Math.min(ih, y1))
        if (x1 - x0 < 1 || y1 - y0 < 1)
            return

        const c = sampler.getContext("2d")
        c.clearRect(0, 0, sampler.width, sampler.height)
        try {
            c.drawImage(wallpaper, x0, y0, x1 - x0, y1 - y0,
                        0, 0, sampler.width, sampler.height)
            const data = c.getImageData(0, 0, sampler.width, sampler.height).data
            let r = 0, g = 0, b = 0, n = 0
            for (let i = 0; i < data.length; i += 4) {
                const a = data[i + 3] / 255
                if (a <= 0.01)
                    continue
                r += data[i] * a
                g += data[i + 1] * a
                b += data[i + 2] * a
                n += a
            }
            if (n <= 0) {
                // Первый кадр после загрузки Image может быть ещё пустым:
                // просим Canvas перерисоваться чуть позже.
                if (root.emptyDraws < 3) {
                    root.emptyDraws++
                    retryTimer.restart()
                }
                return
            }
            root.emptyDraws = 0
            root.averageColor = Qt.rgba(r / n / 255, g / n / 255, b / n / 255, 1)
            root.ready = true
            if (!root.announced) {
                root.announced = true
                console.info("[widgets/backdrop] " + root.rectWidth + "x"
                             + root.rectHeight + " luminance="
                             + root.luminanceOf(root.averageColor).toFixed(3)
                             + " ink=" + root.ink)
            }
        } catch (e) {
            // Локальные file:// обычно доступны; если политика безопасности
            // запретила чтение пикселей — остаёмся на fallbackColor.
            root.ready = false
            console.info("[widgets/backdrop] sampling недоступен: " + e)
        }
    }

    // Служебные элементы не должны быть видны и не должны ловить ввод.
    width: 16
    height: 16
    opacity: 1
    z: -1000

    Component.onCompleted: root.schedule()

    Image {
        id: wallpaper

        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        visible: false
        width: Math.max(1, root.screenWidth)
        height: Math.max(1, root.screenHeight)

        onStatusChanged: {
            if (status === Image.Ready)
                root.schedule()
            else if (status === Image.Error)
                root.ready = false
        }
    }

    Canvas {
        id: sampler

        width: 16
        height: 16
        opacity: 0.001
        onPaint: root.collectSample()
        onAvailableChanged: {
            if (available)
                root.schedule()
        }
    }

    Timer {
        id: retryTimer

        interval: 50
        repeat: false
        onTriggered: root.paint()
    }

    Timer {
        id: debounce

        interval: 100
        repeat: false
        onTriggered: root.paint()
    }

    onSourceChanged: {
        root.ready = false
        root.announced = false
        root.schedule()
    }
    onScreenWidthChanged: root.schedule()
    onScreenHeightChanged: root.schedule()
    onRectXChanged: root.schedule()
    onRectYChanged: root.schedule()
    onRectWidthChanged: root.schedule()
    onRectHeightChanged: root.schedule()
    onFallbackColorChanged: {
        if (!root.ready)
            root.averageColor = root.fallbackColor
    }

    property bool announced: false
    property int emptyDraws: 0
}
