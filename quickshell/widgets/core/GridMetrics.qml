import QtQuick
import Quickshell

// Геометрия сетки одного экрана (раздел 5 ТЗ).
//
// Принцип: физический размер клетки примерно постоянен, а число клеток
// вычисляется под конкретный экран/DPI. Все размеры — в логических пикселях
// QML; физическое выравнивание делается через dpr.
//
// Компонент реактивный: при изменении геометрии экрана, scale или плотности
// все производные свойства пересчитываются без перезапуска shell.
QtObject {
    id: root

    // Экран Quickshell (ShellScreen), для которого считается сетка.
    required property var screen

    // Пикселей на 1dp при 160 dpi: density * 25.4 / 160.
    readonly property real dp: density * 25.4 / 160

    readonly property real dpr: {
        const value = root.screen ? root.screen.devicePixelRatio : 1
        return (isFinite(value) && value > 0) ? value : 1
    }

    // Логическая плотность экрана, px/мм.
    readonly property real rawDensity: {
        const value = root.screen ? root.screen.logicalPixelDensity : 0
        return (isFinite(value) && value > 0) ? value : 0
    }

    // Плотность с учётом override и фолбэка для битого EDID (раздел 5.1, п.1).
    //
    // На Wayland/Qt physicalPixelDensity уже считается в логических пикселях
    // на миллиметр и учитывает scale: 1920x1200 при физических 300x190 мм даёт
    // 6.36 px/мм, тогда как logicalPixelDensity здесь — просто 96 dpi (3.78).
    // Для одинакового физического размера клетки берём physicalPixelDensity.
    readonly property real physicalDensity: {
        const value = root.screen ? root.screen.physicalPixelDensity : 0
        return (isFinite(value) && value > 0) ? value : 0
    }

    readonly property real density: {
        if (Config.dpiOverride > 0)
            return Config.dpiOverride
        if (root.physicalDensity >= 2 && root.physicalDensity <= 12)
            return root.physicalDensity
        if (root.rawDensity >= 2 && root.rawDensity <= 12)
            return root.rawDensity
        return 3.7795275591 / root.dpr // 96 dpi в px/мм при текущем scale
    }

    readonly property real targetCellPx: Config.cellTargetMm * density
    readonly property int gap: Math.max(1, Math.round(targetCellPx * Config.gapRatio))
    readonly property int outerMargin: Math.round(Config.outerMarginMm * density)

    // Область сетки: окно слоя минус зарезервированные зоны минус внешний
    // отступ. Размер окна, а не экрана, важен потому, что layer-shell сам
    // ужимает поверхность под панели других клиентов (exclusionMode Normal).
    readonly property int screenWidth: root.screen ? root.screen.width : 0
    readonly property int screenHeight: root.screen ? root.screen.height : 0
    // Задаются DesktopLayer по фактическим размерам PanelWindow.
    property int windowWidth: 0
    property int windowHeight: 0
    readonly property int areaWidth: windowWidth > 0 ? windowWidth : screenWidth
    readonly property int areaHeight: windowHeight > 0 ? windowHeight : screenHeight
    readonly property real areaX: Config.reservedLeft + outerMargin
    readonly property real areaY: Config.reservedTop + outerMargin
    readonly property real areaW:
        Math.max(1, areaWidth - Config.reservedLeft - Config.reservedRight
                    - 2 * outerMargin)
    readonly property real areaH:
        Math.max(1, areaHeight - Config.reservedTop - Config.reservedBottom
                    - 2 * outerMargin)

    // Столбцы ограничены minCols/maxCols (раздел 5.1, п.5).
    readonly property int cols:
        Math.max(1, Math.min(Config.maxCols,
                               Math.max(Config.minCols,
                                        Math.round((areaW + gap) / (targetCellPx + gap)))))

    // Клетка квадратная; строки добираются по остатку высоты (п.6).
    readonly property int cell:
        Math.max(1, Math.floor((areaW + gap) / cols - gap) || 0)
    readonly property int rows:
        Math.max(1, Math.floor((areaH + gap) / (cell + gap)) || 0)

    readonly property real gridW: cols * cell + (cols - 1) * gap
    readonly property real gridH: rows * cell + (rows - 1) * gap

    // Остаток распределяется в отступы: сетка центрируется (п.7).
    readonly property real originX: snap(areaX + (areaW - gridW) / 2)
    readonly property real originY: snap(areaY + (areaH - gridH) / 2)

    // Фактический размер клетки в миллиметрах — для проверки приёмки.
    readonly property real cellMm: density > 0 ? cell / density : 0
    // Сигнатура сетки: по ней в LayoutStore хранятся отдельные раскладки.
    readonly property string signature: cols + "x" + rows
    readonly property string screenName: root.screen ? root.screen.name : ""

    // Выравнивание координаты на физические пиксели (п.7).
    function snap(value: real): real {
        return Math.round(value * root.dpr) / root.dpr
    }

    function pixelWidth(count: int): real {
        return count * root.cell + Math.max(0, count - 1) * root.gap
    }

    function pixelHeight(count: int): real {
        return count * root.cell + Math.max(0, count - 1) * root.gap
    }

    // Прямоугольник виджета в логических пикселях.
    function cellRect(col: int, row: int, widthCells: int, heightCells: int): var {
        return {
            x: root.originX + col * (root.cell + root.gap),
            y: root.originY + row * (root.cell + root.gap),
            width: pixelWidth(widthCells),
            height: pixelHeight(heightCells)
        }
    }

    function logState(): void {
        console.info("[widgets/grid] screen=" + root.screenName
                     + " screen=" + root.screenWidth + "x" + root.screenHeight
                     + " window=" + root.areaWidth + "x" + root.areaHeight
                     + " dpr=" + root.dpr.toFixed(2)
                     + " density=" + root.density.toFixed(2) + "px/mm"
                     + " (logical=" + root.rawDensity.toFixed(2)
                     + " physical=" + root.physicalDensity.toFixed(2) + ")"
                     + " grid=" + root.cols + "x" + root.rows
                     + " cell=" + root.cell + "px/" + root.cellMm.toFixed(1) + "mm"
                     + " gap=" + root.gap + " dp=" + root.dp.toFixed(2)
                     + " areaY=" + root.areaY + " areaH=" + root.areaH
                     + " gridH=" + root.gridH
                     + " origin=" + root.originX + "," + root.originY)
    }

    // Логируем после того, как все зависимые биндинги (в т.ч. rows)
    // пересчитались: прямо в обработчике onCellChanged часть значений ещё
    // старая. Qt.callLater не требует дочернего Timer, которого у QtObject нет.
    property bool logScheduled: false

    function scheduleLog(): void {
        if (root.logScheduled)
            return
        root.logScheduled = true
        Qt.callLater(function() {
            root.logScheduled = false
            root.logState()
        })
    }

    onCellChanged: scheduleLog()
    onColsChanged: scheduleLog()
    onRowsChanged: scheduleLog()
    onAreaWidthChanged: scheduleLog()
    onAreaHeightChanged: scheduleLog()
    onOriginXChanged: scheduleLog()
    onOriginYChanged: scheduleLog()
    Component.onCompleted: scheduleLog()
}
