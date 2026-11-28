pragma Singleton

import QtQuick
import Quickshell

// Единая точка правды для оформления — Material Design 3 (Material You).
//
// Цвета строятся как MD3-схема из сида pywal: акцент даёт primary/secondary/
// tertiary палитры, фон обоев — нейтральную палитру поверхностей. Тон
// (tone 0..100) — это перцептивная светлота L*: в tone() подбирается такая
// HSL-светлота при сохранении оттенка, чтобы относительная яркость совпала
// с Y(L*) из спецификации M3. Роли разложены по тонам ровно как в
// references/color-system.md, поэтому контраст пар onX/X сохраняется.
//
// Отличие от «стерильного» M3: оболочка живёт поверх обоев, поэтому часть
// поверхностей (бар, попап, док) — тональные роли с прозрачностью ~90–98%.
// Это осознанное расширение: цвет берётся из тональной палитры, а не
// подбирается на глаз, поэтому динамическая тема и контраст не ломаются.
//
// Шрифт — Google Sans (Material-класс), иконки — Nerd Font.
// Типографика, формы, отступы и движение — токены из скилла material-3.
Singleton {
    id: root

    // ===================== Цветовая схема ===============================
    // Сид динамической темы. Меняется вместе с палитрой pywal.
    readonly property color seed: Wal.accent
    readonly property bool isDark: root.relativeLuminance(Wal.background) < 0.5

    // Схема целиком: пересобирается при смене обоев/акцента.
    readonly property var scheme: root.buildScheme()

    // Роли MD3 плоскими свойствами — основной способ обращения в разметке.
    readonly property color primary: root.scheme.primary
    readonly property color primaryContainer: root.scheme.primaryContainer
    readonly property color secondary: root.scheme.secondary
    readonly property color secondaryContainer: root.scheme.secondaryContainer
    readonly property color tertiary: root.scheme.tertiary
    readonly property color tertiaryContainer: root.scheme.tertiaryContainer
    readonly property color error: root.scheme.error
    readonly property color errorContainer: root.scheme.errorContainer
    readonly property color surface: root.scheme.surface
    readonly property color surfaceVariant: root.scheme.surfaceVariant
    readonly property color surfaceDim: root.scheme.surfaceDim
    readonly property color surfaceBright: root.scheme.surfaceBright
    readonly property color surfaceContainerLowest: root.scheme.surfaceContainerLowest
    readonly property color surfaceContainerLow: root.scheme.surfaceContainerLow
    readonly property color surfaceContainer: root.scheme.surfaceContainer
    readonly property color surfaceContainerHigh: root.scheme.surfaceContainerHigh
    readonly property color surfaceContainerHighest: root.scheme.surfaceContainerHighest
    readonly property color outline: root.scheme.outline
    readonly property color outlineVariant: root.scheme.outlineVariant
    readonly property color inverseSurface: root.scheme.inverseSurface
    readonly property color inverseOnSurface: root.scheme.inverseOnSurface
    readonly property color inversePrimary: root.scheme.inversePrimary
    readonly property color scrim: root.scheme.scrim
    readonly property color shadow: root.scheme.shadow

    // Пользовательские роли вне M3 (состояния батареи и предупреждения).
    readonly property color success: root.isDark ? "#3DDC84" : "#006E2C"
    readonly property color warning: root.isDark ? "#F2B23C" : "#8A5A00"

    // Прозрачные («вуалированные») поверхности оболочки поверх обоев.
    // Это те же тональные роли, только с альфой — не произвольные цвета.
    readonly property color barSurface: root.veil(root.surfaceContainer, 0.94)
    readonly property color panelSurface: root.veil(root.surfaceContainerLow, 0.985)
    readonly property color sheetSurface: root.veil(root.surfaceContainerHigh, 0.99)
    readonly property color menuSurfaceSolid: root.veil(root.surfaceContainerHigh, 0.995)

    // ===================== Блюр и контраст ==============================
    // Настройки «Оформление»: сила собственных dual Kawase шейдеров и
    // плотность тонировки карточек поверх blur. Обе — 0..1, дефолт 0.5.
    // Значения хранятся в Settings (state/quickshell/settings.json).
    function settingUnit(key, fallback) {
        const stored = Settings.value(key, fallback);
        const value = Number(stored);
        return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : fallback;
    }

    readonly property real blurStrength: root.settingUnit("blur.strength", 0.5)
    readonly property real cardContrast: root.settingUnit("blur.cardContrast", 0.5)

    // Радиус собственных шейдеров (обои блокировки, обложка плеера).
    // 0 — почти без размытия, 1 — вдвое больше базового радиуса.
    function blurRadius(base) {
        return Math.max(0, Number(base) * root.blurStrength * 2);
    }

    // Плотность тональной подложки поверх размытого фона: выше contrast —
    // плотнее карточка и контрастнее текст, ниже — сильнее видно blur.
    // Дефолт 0.5 даёт прежние 0.82/0.86.
    readonly property real panelAlpha: 0.67 + 0.30 * root.cardContrast
    readonly property real sheetAlpha: 0.73 + 0.26 * root.cardContrast
    readonly property real artTintOpacity: 0.59 + 0.30 * root.cardContrast

    // Панели поверх окон: фон под ними размывает композитор по запросу
    // BackgroundEffect (ext-background-effect-v1), поэтому плотность ниже,
    // чем у чисто тональной поверхности.
    readonly property color panelBlurSurface: root.veil(root.surfaceContainerLow, root.panelAlpha)
    readonly property color sheetBlurSurface: root.veil(root.surfaceContainerHigh, root.sheetAlpha)

    // Подложка диалогов/меню: M3 поверхность + затемнение фона (scrim).
    readonly property color scrimOverlay: root.withAlpha(root.scrim, 0.45)

    // Заливки сверх поверхности: M3 state layer (hover/focus/pressed).
    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.10
    readonly property real statePressed: 0.12
    readonly property real stateDragged: 0.16
    readonly property real disabledContent: 0.38
    readonly property real disabledContainer: 0.12

    // ===================== Типографика ==================================
    // Google Sans — Material-класс; Nerd Font — глифы-иконки.
    readonly property string fontFamily: "Google Sans"
    readonly property string iconFontFamily: "JetBrainsMono Nerd Font"

    // Числовые метрики M3 (sp, line height, tracking) — для расчётов.
    readonly property var typescale: ({
        displayLarge: { size: 57, weight: 400, line: 64, tracking: -0.25 },
        displayMedium: { size: 45, weight: 400, line: 52, tracking: 0 },
        displaySmall: { size: 36, weight: 400, line: 44, tracking: 0 },
        headlineLarge: { size: 32, weight: 400, line: 40, tracking: 0 },
        headlineMedium: { size: 28, weight: 400, line: 36, tracking: 0 },
        headlineSmall: { size: 24, weight: 400, line: 32, tracking: 0 },
        titleLarge: { size: 22, weight: 500, line: 28, tracking: 0 },
        titleMedium: { size: 16, weight: 500, line: 24, tracking: 0.15 },
        titleSmall: { size: 14, weight: 500, line: 20, tracking: 0.1 },
        bodyLarge: { size: 16, weight: 400, line: 24, tracking: 0.5 },
        bodyMedium: { size: 14, weight: 400, line: 20, tracking: 0.25 },
        bodySmall: { size: 12, weight: 400, line: 16, tracking: 0.4 },
        labelLarge: { size: 14, weight: 500, line: 20, tracking: 0.1 },
        labelMedium: { size: 12, weight: 500, line: 16, tracking: 0.5 },
        labelSmall: { size: 11, weight: 500, line: 16, tracking: 0.5 }
    })

    // Готовые font-значения: Text { font: Theme.typeTitleMedium }.
    readonly property font typeDisplayLarge: Qt.font({ family: root.fontFamily, pixelSize: 57, weight: 400, letterSpacing: -0.25 })
    readonly property font typeDisplayMedium: Qt.font({ family: root.fontFamily, pixelSize: 45, weight: 400, letterSpacing: 0 })
    readonly property font typeDisplaySmall: Qt.font({ family: root.fontFamily, pixelSize: 36, weight: 400, letterSpacing: 0 })
    readonly property font typeHeadlineLarge: Qt.font({ family: root.fontFamily, pixelSize: 32, weight: 400, letterSpacing: 0 })
    readonly property font typeHeadlineMedium: Qt.font({ family: root.fontFamily, pixelSize: 28, weight: 400, letterSpacing: 0 })
    readonly property font typeHeadlineSmall: Qt.font({ family: root.fontFamily, pixelSize: 24, weight: 400, letterSpacing: 0 })
    readonly property font typeTitleLarge: Qt.font({ family: root.fontFamily, pixelSize: 22, weight: 500, letterSpacing: 0 })
    readonly property font typeTitleMedium: Qt.font({ family: root.fontFamily, pixelSize: 16, weight: 500, letterSpacing: 0.15 })
    readonly property font typeTitleSmall: Qt.font({ family: root.fontFamily, pixelSize: 14, weight: 500, letterSpacing: 0.1 })
    readonly property font typeBodyLarge: Qt.font({ family: root.fontFamily, pixelSize: 16, weight: 400, letterSpacing: 0.5 })
    readonly property font typeBodyMedium: Qt.font({ family: root.fontFamily, pixelSize: 14, weight: 400, letterSpacing: 0.25 })
    readonly property font typeBodySmall: Qt.font({ family: root.fontFamily, pixelSize: 12, weight: 400, letterSpacing: 0.4 })
    readonly property font typeLabelLarge: Qt.font({ family: root.fontFamily, pixelSize: 14, weight: 500, letterSpacing: 0.1 })
    readonly property font typeLabelMedium: Qt.font({ family: root.fontFamily, pixelSize: 12, weight: 500, letterSpacing: 0.5 })
    readonly property font typeLabelSmall: Qt.font({ family: root.fontFamily, pixelSize: 11, weight: 500, letterSpacing: 0.5 })

    // --- Material 3 Expressive: инфраструктура --------------------------
    // Оставлена в системе для будущего включения: variable-шрифт, пружины
    // и emphasized-стили. Текущий UI использует обычные type*-стили выше.
    readonly property string fontFamilyExpressive: "Roboto Flex"
    readonly property real weightBold: 720
    readonly property real weightEmphasized: 820
    readonly property real widthTight: 90
    readonly property real widthNarrow: 84

    readonly property font typeEmphasizedDisplaySmall: Qt.font({ family: root.fontFamilyExpressive, pixelSize: 38, weight: 820, letterSpacing: -0.6, variableAxes: ({ "wght": 820, "wdth": 86, "opsz": 52 }) })
    readonly property font typeEmphasizedHeadlineSmall: Qt.font({ family: root.fontFamilyExpressive, pixelSize: 26, weight: 800, letterSpacing: -0.2, variableAxes: ({ "wght": 800, "wdth": 86, "opsz": 36 }) })
    readonly property font typeEmphasizedTitleLarge: Qt.font({ family: root.fontFamilyExpressive, pixelSize: 24, weight: 780, letterSpacing: -0.1, variableAxes: ({ "wght": 780, "wdth": 88, "opsz": 30 }) })
    readonly property font typeEmphasizedTitleMedium: Qt.font({ family: root.fontFamilyExpressive, pixelSize: 17, weight: 740, letterSpacing: 0.1, variableAxes: ({ "wght": 740, "wdth": 90, "opsz": 26 }) })
    readonly property font typeEmphasizedLabelLarge: Qt.font({ family: root.fontFamilyExpressive, pixelSize: 14, weight: 720, letterSpacing: 0.15, variableAxes: ({ "wght": 720, "wdth": 90, "opsz": 15 }) })

    readonly property var springs: ({
        spatial: { spring: 5.5, damping: 0.32 },
        spatialFast: { spring: 7.0, damping: 0.40 },
        spatialSlow: { spring: 4.2, damping: 0.28 },
        effects: { spring: 16.0, damping: 0.80 },
        effectsFast: { spring: 22.0, damping: 0.90 }
    })

    // ===================== Формы ========================================
    // Токены M3: кнопки/чипы — full, карточки — medium, листы/диалоги — xl.
    readonly property var shape: ({
        none: 0,
        xs: 4,
        sm: 8,
        md: 12,
        lg: 16,
        xl: 28,
        xlIncreased: 32,
        full: 999
    })

    // ===================== Отступы (8dp-grid) ===========================
    readonly property var space: ({
        xs: 4,
        sm: 8,
        md: 12,
        lg: 16,
        xl: 24,
        xxl: 32,
        xxxl: 48
    })

    // Иконки: M3 использует 24dp по умолчанию, 20 — в плотных списках.
    readonly property var iconSize: ({
        sm: 16,
        md: 20,
        lg: 24,
        xl: 32
    })

    // Высота интерактивных целей M3 (min 40–56 для списков, 48 — тач).
    readonly property int touchTarget: 48
    readonly property int iconButtonSize: 40
    readonly property int buttonHeight: 40
    readonly property int listItemHeight: 56
    readonly property int appBarHeight: 56

    // ===================== Поверхности и отступы оболочки ===============
    // Бар
    readonly property int barHeight: 48
    readonly property int barPadding: 12
    // Иконка бара живёт в квадрате 40×40; слоты стоят вплотную, поэтому
    // центры одиночных значков идут с шагом 40. Группа статуса внутри
    // плотнее — она читается как одна кнопка.
    readonly property int barIconSlot: root.iconButtonSize
    readonly property int barIconGap: 0
    readonly property color barBackground: root.barSurface
    readonly property color barForeground: root.scheme.onSurface

    // Часы
    readonly property int clockFontSize: 15

    // Рабочие столы: активный — вытянутая пилюля primary, как индикатор
    // навигации M3; неактивные — точки outline-variant.
    readonly property int workspaceDotSize: 6
    readonly property int workspaceActiveDotSize: 18
    readonly property int workspaceSpacing: 8
    readonly property color workspaceActiveColor: root.primary
    // Неактивные точки — on-surface-variant с прозрачностью: в M3
    // второстепенные элементы навигации именно так и приглушаются.
    readonly property color workspaceInactiveColor: root.withAlpha(root.scheme.onSurfaceVariant, 0.55)

    // Кнопка статуса в баре
    readonly property int controlHeight: 32
    readonly property int controlRadius: root.shape.full

    // Попап быстрых настроек: ширина общая для всех видов и ограничена.
    readonly property int quickWidth: 400
    readonly property int quickRadius: root.shape.xl
    readonly property int quickPadding: 16
    readonly property int quickCircleSize: 32
    readonly property int quickTileHeight: 64
    readonly property int quickTileRadius: root.shape.xl
    readonly property int quickTileSpacing: 8
    readonly property int quickHeaderHeight: 56
    readonly property int quickRowHeight: 56
    readonly property int quickSectionHeight: 32

    // --- нижний док -------------------------------------------------------
    // Карточка живёт внутри окна постоянного размера: поверхность не меняет
    // размер на кадр анимации (иначе композитор пересоздаёт буфер), поэтому
    // «плавный размер» — это размеры карточки, а не окна.
    readonly property int dockHeight: 68
    readonly property int dockPadding: 10
    readonly property int dockSpacing: 8
    // Базовые размеры; пользователь меняет их в DockSettings, а при
    // переполнении ряд ужимается целиком.
    readonly property int dockButtonSize: 44
    readonly property int dockIconSize: 26
    // Шире док не растёт: дальше уменьшаются иконки.
    readonly property int dockMaxWidth: 520
    readonly property int dockRadius: root.shape.xl
    readonly property int dockPanelWidth: 640
    readonly property int dockPanelHeight: 420
    readonly property int dockPanelPadding: 16
    readonly property int dockPanelRadius: root.shape.xl
    readonly property int dockGridColumns: 6
    readonly property int dockGridCellHeight: 92
    // Запас окна под большую панель: выше неё карточка не растёт.
    readonly property int dockSurfaceHeight: 520
    readonly property int dockBottomMargin: 10
    // Зона активации — узкая полоса у нижней кромки экрана. Ограничена по
    // ширине, чтобы не перехватывать углы, где тянут границы окон.
    readonly property int dockActivationHeight: 6
    readonly property int dockActivationWidth: 720
    // Сколько док ждёт после ухода курсора, прежде чем спрятаться.
    readonly property int dockLingerCompact: 220
    readonly property int dockLingerExpanded: 1400
    // Порог свайпа вверх по компактной полосе (px суммарной дельты).
    readonly property int dockSwipeThreshold: 48
    // Оверскролл вверх в списке приложений: сколько пикселей нужно
    // протянуть за верхний край, чтобы закрыть панель.
    readonly property int dockOverscrollClose: 96

    // --- Material 3 Expressive: док --------------------------------------
    // Быстрее общего motion-набора панелей: док — прямой манипулятор,
    // он должен отвечать почти сразу. Появление (выезд/уход) чуть длиннее
    // морфа контейнера, чтобы само движение из-за края читалось отдельно,
    // а не сливалось с изменением размера. Overshoot в кривой даёт
    // «пружинку» expressive, не превращая движение в цирк.
    readonly property int dockRevealDuration: 220
    readonly property int dockMorphDuration: 160
    readonly property int dockFadeDuration: 130
    readonly property int dockHideDuration: 220
    // ВАЖНО: easing.bezierCurve в Qt — это НЕ CSS cubic-bezier. Список
    // задаётся группами по три точки «[cx1, cy1, cx2, cy2, endx, endy]»,
    // и последняя точка обязана быть (1, 1). С 4 значениями (как в CSS)
    // Qt молча игнорирует кривую, и easing вырождается в линейный: движение
    // идёт с постоянной скоростью и в конце резко обрывается — это и
    // читалось как «контент дёргается в конце анимации».
    readonly property var curveDockExpressive: [0.2, 1.18, 0.24, 1.0, 1.0, 1.0]
    readonly property var curveDockExit: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    // Критически задемпфированная пружина прокрутки (тик 16 мс).
    readonly property real dockScrollOmega: 0.032
    readonly property real dockScrollStop: 0.4
    // Изменение высоты панели в fit-режиме: медленный вход, быстрая
    // середина и мягкое торможение — заметно нелинейно, без перелёта
    // за маску ввода.
    readonly property int dockResizeDuration: 240
    readonly property var curveDockResize: [0.4, 0.0, 0.2, 1.0, 1.0, 1.0]

    // Карточки уведомлений и Центр уведомлений.
    readonly property int notificationWidth: 380
    readonly property int notificationCenterWidth: 400
    readonly property int notificationRadius: root.shape.xl
    readonly property int notificationPadding: 16
    readonly property int notificationSpacing: 8

    readonly property color accent: root.primary

    // --- Material-роли для системы виджетов -------------------------------
    // Виджеты используют тот же Wal-акцент и нейтральную базу, что панели
    // оболочки, поэтому рабочий стол не выбивается из оформления.
    readonly property var colors: ({
        surface: root.quickBackground,
        onSurface: root.scheme.onSurface,
        surfaceVariant: root.quickTile,
        onSurfaceVariant: root.scheme.onSurfaceVariant,
        primary: root.primary,
        onPrimary: root.scheme.onPrimary,
        primaryContainer: root.primaryContainer,
        onPrimaryContainer: root.scheme.onPrimaryContainer,
        secondary: root.secondary,
        onSecondary: root.scheme.onSecondary,
        secondaryContainer: root.secondaryContainer,
        onSecondaryContainer: root.scheme.onSecondaryContainer,
        tertiary: root.tertiary,
        onTertiary: root.scheme.onTertiary,
        tertiaryContainer: root.tertiaryContainer,
        onTertiaryContainer: root.scheme.onTertiaryContainer,
        outline: root.outline,
        outlineVariant: root.outlineVariant,
        error: root.error,
        onError: root.scheme.onError
    })

    // Нейтральный системный вариант: без акцента, только база/текст.
    readonly property var neutralColors: ({
        surface: root.quickBackground,
        onSurface: root.scheme.onSurface,
        surfaceVariant: root.quickTile,
        onSurfaceVariant: root.scheme.onSurfaceVariant,
        primary: root.scheme.onSurface,
        onPrimary: root.surface,
        primaryContainer: root.quickTileActive,
        onPrimaryContainer: root.scheme.onSurface,
        secondary: root.quickTile,
        onSecondary: root.scheme.onSurface,
        tertiary: root.quickSwitchOff,
        outline: root.outlineVariant,
        error: root.error
    })

    function colorsFor(mode) {
        return mode === "neutral" ? root.neutralColors : root.colors;
    }

    // ===================== Легаси-алиасы (совместимость) ================
    // Панели быстрых настроек намеренно почти нейтральные: тональная
    // поверхность из нейтральной палитры, от обоев остаётся лёгкий оттенок.
    // Панель быстрых настроек — отдельная layer-поверхность
    // (quickshell-quick) с BackgroundEffect; см. BLUR.md.
    readonly property color quickBackground: root.sheetBlurSurface
    readonly property color quickBorder: root.outlineVariant
    readonly property color quickTile: root.surfaceContainerHigh
    readonly property color quickTileHover: root.surfaceContainerHighest
    readonly property color quickTileActive: root.secondaryContainer
    readonly property color quickCircleOff: root.surfaceContainerHighest
    readonly property color quickSwitchOff: root.surfaceContainerHighest
    readonly property color quickSeparator: root.outlineVariant
    readonly property color quickText: root.scheme.onSurface
    readonly property color quickTextDim: root.scheme.onSurfaceVariant
    readonly property color quickIconOn: root.scheme.onPrimary
    readonly property color neutralSurface: root.surface
    readonly property color menuSurface: root.menuSurfaceSolid
    readonly property color menuSurfaceHover: root.surfaceContainerHighest
    readonly property color menuBorder: root.outlineVariant

    // Цвета состояний батареи (как в статус-баре Android).
    readonly property color chargeColor: root.success
    readonly property color lowColor: root.error
    readonly property color mediumColor: root.warning
    readonly property color warningColor: root.warning

    // ===================== Движение (M3) ================================
    // Длительности из m3 (short/medium/long) и кривые emphasized/standard.
    readonly property int motionShort1: 50
    readonly property int motionShort2: 100
    readonly property int motionShort3: 150
    readonly property int motionShort4: 200
    readonly property int motionMedium1: 250
    readonly property int motionMedium2: 300
    readonly property int motionMedium3: 350
    readonly property int motionMedium4: 400
    readonly property int motionLong1: 450
    readonly property int motionLong2: 500

    // Свайп карточки уведомления: улёт за край (accelerate) и упругий
    // возврат (decelerate). Кривые — curveEmphasizedAccelerate/Decelerate.
    readonly property int motionSwipeExit: 150
    readonly property int motionSwipeReturn: 250

    // Формат списка — три точки, конец (1, 1); см. комментарий у дока.
    readonly property var curveEmphasized: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var curveEmphasizedDecelerate: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var curveEmphasizedAccelerate: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property var curveStandard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var curveStandardDecelerate: [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var curveStandardAccelerate: [0.3, 0.0, 1.0, 1.0, 1.0, 1.0]

    // Масштабы входа/выхода: 92% у видов (fade through) и 80% у элементов
    // списков (m3 enter/exit), чтобы переходы читались одинаково.
    readonly property real motionFadeThroughScale: 0.92
    readonly property real motionElementScale: 0.8

    // Жест «назад»: за пальцем вид едет лишь на четверть ширины, остальное
    // делают прозрачность и масштаб — иначе в середине жеста оба вида
    // оказываются за краями панели и смотреть не на что.
    readonly property real gestureParallax: 0.25

    // ===================== Функции ======================================

    // Собирает полную схему ролей M3 из сида и фона обоев.
    function buildScheme() {
        const dark = root.isDark;
        const p = function (tone) {
            return root.toneColor(root.seed, tone, 0.62);
        };
        // Secondary — тот же оттенок, но заметно тише (низкая хрома).
        const s = function (tone) {
            return root.toneColor(root.seed, tone, 0.30);
        };
        // Tertiary — соседний акцент (+60° по кругу оттенков).
        const t = function (tone) {
            const hue = root.hueOf(root.seed);
            const base = Qt.hsla((hue + 60 / 360) % 1, Math.min(root.saturationOf(root.seed), 0.45), 0.5, 1);
            return root.toneColor(base, tone, 0.45);
        };
        // Нейтральные поверхности наследуют оттенок обоев, но почти серые.
        const n = function (tone) {
            return root.toneColor(Wal.background, tone, 0.08);
        };
        // Neutral-variant — чуть цветнее нейтрального (иконки, обводки).
        const nv = function (tone) {
            return root.toneColor(root.seed, tone, 0.16);
        };

        if (dark) {
            return {
                primary: p(80),
                onPrimary: p(20),
                primaryContainer: p(30),
                onPrimaryContainer: p(90),
                secondary: s(80),
                onSecondary: s(20),
                secondaryContainer: s(30),
                onSecondaryContainer: s(90),
                tertiary: t(80),
                onTertiary: t(20),
                tertiaryContainer: t(30),
                onTertiaryContainer: t(90),
                error: "#F2B8B5",
                onError: "#601410",
                errorContainer: "#8C1D18",
                onErrorContainer: "#F9DEDC",
                surface: n(6),
                onSurface: n(90),
                surfaceVariant: nv(30),
                onSurfaceVariant: nv(80),
                surfaceDim: n(6),
                surfaceBright: n(24),
                surfaceContainerLowest: n(4),
                surfaceContainerLow: n(10),
                surfaceContainer: n(12),
                surfaceContainerHigh: n(17),
                surfaceContainerHighest: n(22),
                outline: nv(60),
                outlineVariant: nv(30),
                inverseSurface: n(90),
                inverseOnSurface: n(20),
                inversePrimary: p(40),
                scrim: "#000000",
                shadow: "#000000"
            };
        }

        return {
            primary: p(40),
            onPrimary: p(100),
            primaryContainer: p(90),
            onPrimaryContainer: p(10),
            secondary: s(40),
            onSecondary: s(100),
            secondaryContainer: s(90),
            onSecondaryContainer: s(10),
            tertiary: t(40),
            onTertiary: t(100),
            tertiaryContainer: t(90),
            onTertiaryContainer: t(10),
            error: "#B3261E",
            onError: "#FFFFFF",
            errorContainer: "#F9DEDC",
            onErrorContainer: "#410E0B",
            surface: n(98),
            onSurface: n(10),
            surfaceVariant: nv(90),
            onSurfaceVariant: nv(30),
            surfaceDim: n(87),
            surfaceBright: n(98),
            surfaceContainerLowest: n(100),
            surfaceContainerLow: n(96),
            surfaceContainer: n(94),
            surfaceContainerHigh: n(92),
            surfaceContainerHighest: n(90),
            outline: nv(50),
            outlineVariant: nv(80),
            inverseSurface: n(20),
            inverseOnSurface: n(95),
            inversePrimary: p(80),
            scrim: "#000000",
            shadow: "#000000"
        };
    }

    // Оттенок цвета в 0..1; у серого QML отдаёт -1.
    function hueOf(color) {
        return color && color.hslHue >= 0 ? color.hslHue : 0;
    }

    function saturationOf(color) {
        return color ? Math.max(0, Math.min(1, color.hslSaturation)) : 0;
    }

    // Относительная яркость WCAG 0..1 — по ней же определяется тёмная тема.
    function relativeLuminance(color) {
        if (!color)
            return 0;
        const channel = function (value) {
            return value <= 0.03928 ? value / 12.92
                                    : Math.pow((value + 0.055) / 1.055, 2.4);
        };
        return 0.2126 * channel(color.r) + 0.7152 * channel(color.g)
             + 0.0722 * channel(color.b);
    }

    // Цель тона: L* (0..100) переводится в Y по формуле CIE Lab.
    function toneLuminance(tone) {
        const value = Math.max(0, Math.min(100, tone));
        if (value <= 0)
            return 0;
        if (value <= 8)
            return value / 903.3;
        const fy = (value + 16) / 116;
        return fy * fy * fy;
    }

    // Цвет заданного тона с сохранением оттенка; хрома ограничена cap.
    // Бинарный поиск по HSL-светлоте: тон в M3 — перцептивная величина,
    // поэтому подгоняется яркость, а не «примерно похожая» светлота.
    function toneColor(base, tone, cap) {
        if (!base)
            return Qt.rgba(0, 0, 0, 1);
        const hue = root.hueOf(base);
        const saturation = Math.min(root.saturationOf(base), cap === undefined ? 1 : cap);
        const target = root.toneLuminance(tone);
        let low = 0;
        let high = 1;
        for (let i = 0; i < 16; ++i) {
            const middle = (low + high) / 2;
            if (root.relativeLuminance(Qt.hsla(hue, saturation, middle, 1)) < target)
                low = middle;
            else
                high = middle;
        }
        return Qt.hsla(hue, saturation, (low + high) / 2, 1);
    }

    // Тональная надбавка M3: поверхность «приподнимается» примесью primary.
    function elevated(color, level) {
        const weights = [0, 0.05, 0.08, 0.11, 0.12, 0.14];
        const index = Math.max(0, Math.min(weights.length - 1, Math.round(level)));
        return root.mix(color, root.primary, weights[index]);
    }

    // Слой состояния M3: наведение/нажатие/фокус.
    function stateLayer(color, opacity) {
        return root.withAlpha(color, opacity);
    }

    // Полупрозрачная поверхность: цвет роли остаётся тональным, альфа — только
    // способ показать обои под оболочкой.
    function veil(color, alpha) {
        return root.withAlpha(color, alpha);
    }

    function withAlpha(color, alpha) {
        if (!color)
            return Qt.rgba(0, 0, 0, alpha);
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    // Подмешивает к цвету серый той же яркости: amount 1 — полностью серый.
    function neutralize(color, amount) {
        if (!color)
            return Qt.rgba(0.1, 0.1, 0.11, 1);
        const luma = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
        return Qt.rgba(color.r + (luma - color.r) * amount,
                       color.g + (luma - color.g) * amount,
                       color.b + (luma - color.b) * amount,
                       color.a);
    }

    function darken(color, factor) {
        if (!color)
            return Qt.rgba(0, 0, 0, 1);
        return Qt.rgba(color.r * factor, color.g * factor, color.b * factor, color.a);
    }

    function mix(a, b, t) {
        if (!a)
            return b;
        if (!b)
            return a;
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t);
    }
}
