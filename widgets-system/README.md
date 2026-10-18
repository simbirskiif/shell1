# Система виджетов рабочего стола для Quickshell

Отдельная конфигурация Quickshell: слой рабочего стола с сеткой и виджетами,
которые лежат в отдельных папках и подключаются по контракту. ТЗ — `ТЗ система
виджетов рабочего стола для Quickshell.md` (в загрузках пользователя).

Реализация идёт по этапам из раздела 12 ТЗ. Сейчас готовы **этапы 1–3**.

## Запуск

```sh
qs -p /home/adm_a/shell/widgets-system
```

Для отдельного тестового окружения (чтобы не трогать пользовательские
XDG-каталоги):

```sh
XDG_RUNTIME_DIR=$PWD/rt/runtime \
XDG_CONFIG_HOME=$PWD/rt/qs-widgets/config \
XDG_STATE_HOME=$PWD/rt/qs-widgets/state \
qs -p widgets-system
```

Погасить запущенную конфигурацию:

```sh
XDG_RUNTIME_DIR=$PWD/rt/runtime qs kill -p widgets-system
```

## Что работает

### Этап 1: слой и сетка

- `Variants` по `Quickshell.screens`: по одному `DesktopLayer` на экран;
  подключение/отключение мониторов и смена геометрии — без перезапуска.
- `PanelWindow` на слое `Bottom`, `exclusionMode: Normal`, `exclusiveZone: 0`.
  Композитор ужимает поверхность под панели других клиентов, поэтому сетка
  считается по фактическому размеру окна (`windowWidth/Height` в
  `GridMetrics`).
- `GridMetrics`: целевая клетка 16 мм, gap 12 %, min/max столбцов,
  центрирование, выравнивание начала сетки по `dpr`.
- Отладочная сетка (`showGrid` в конфиге).

### Этап 2: реестр и загрузка

- `WidgetRegistry` сканирует пути поиска в порядке приоритета:
  1. `widgets.extraPaths` из конфига;
  2. `$QS_WIDGET_PATH` (через `:`);
  3. `$XDG_CONFIG_HOME/quickshell/widgets`;
  4. `<shellDir>/builtin-widgets`;
  5. `/usr/share/quickshell-widgets`.
  Глубина — 1–2 вложенные папки с `manifest.json`; симлинки не
  разворачиваются, циклов нет.
- Валидация манифеста: обязательны `schema` (1), `id` (обратный DNS), `name`,
  `size`; `entry` должен существовать; неизвестные поля игнорируются.
  Невалидные манифесты попадают в `WidgetRegistry.problems` и не загружаются,
  конфликты `id` — в `conflicts`, побеждает путь с большим приоритетом.
- Размеры по разделу 3.2: диапазон `min/max/default` или список `allowed`
  (`allowed` важнее диапазона), формат `строки×столбцы` (`x` или `*`),
  `default` приводится к ближайшему допустимому, `scalable` учитывает
  единственный размер.
- `WidgetHost` — карточка экземпляра: подложка (пока простой `Rectangle`),
  padding/radius от `GridMetrics`, `Loader.setSource(url, { ctx })`.
- `WidgetContext` (`ctx`) — `colors`, `colorMode`, `isDark`, `rows`, `cols`,
  `width`, `height`, `cell`, `dp`, `sizeClass`, `material`, `editing`,
  `preview`, `screen`, `settings`, `setSetting(key, value)`.
- Настройки из `manifest.settings` (`bool`, `string`, `int`, `real`, `enum`,
  `color`) рендерятся в `ctx.settings`; `ctx.setSetting()` пока пишет в
  память (персистентность — этап 4, UI — этап 6).
- Ошибка загрузки QML локализуется в карточке с названием, иконкой, коротким
  текстом и кнопками «Перезагрузить»/«Удалить». Остальные виджеты работают.
  Ошибка пишется в лог с id виджета.
- Удалённая с диска папка оставляет экземпляр в раскладке в виде
  плейсхолдера «виджет недоступен» с кнопкой удаления.
- Горячая перезагрузка: `FileView.watchChanges` на манифестах, QML-файлах и
  папках; при изменении QML перезагружаются только экземпляры этого виджета.
  Для обхода кэша QML в URL добавляется `?v=<номер>`.
- Маска ввода `Region` строится из прямоугольников видимых карточек; клики
  вне карточек проходят в окна под слоем.

### Этап 3: тема и материалы

- `Theme` отдаёт палитру Material 3 в светлой/тёмной схеме (`theme` в
  конфиге). Два режима цвета: `accent` — палитра shell, `widget` — палитра из
  `manifest.palette` с подстановкой недостающих ролей из shell.
- Режим выбирается глобально (`defaults.colorMode`) и переопределяется на
  экземпляре. Если виджет не поддерживает режим (`colorModes`), берётся первый
  поддерживаемый.
- `MaterialRegistry` ищет материалы в
  `$XDG_CONFIG_HOME/quickshell/widgets/materials` (пользовательские) и
  `<shellDir>/materials` (встроенные) по `meta.json` + `Material.qml`.
  Пользовательские важнее; новые материалы и правки QML подхватываются без
  перезапуска.
- Встроенные материалы: `solid`, `transparent`, `gradient`, `grain` (PNG-шум),
  `glass` (размытие обоев через `QtQuick.Effects.MultiEffect`, тонировка и
  рамка). Скрипт `qsb` в системе отсутствует, поэтому шейдерные `.frag/.qsb`
  заменены на растровый шум и `MultiEffect`; контракт материала от этого не
  меняется.
- Обои для `glass` берутся из `wallpaper` конфига, иначе из
  `~/.config/hypr/hyprpaper.conf`, иначе из `hyprctl hyprpaper listactive`.
- Материал и режим цвета меняются на лету: перезагружается только материал,
  контент виджета остаётся; `ctx.colors`/`ctx.material` обновляются.
- Материал ограничен полем `materials` манифеста (`["any"]` или список id).

IPC для проверки и будущего попапа:

```sh
qs ipc -p widgets-system call widgets state
qs ipc -p widgets-system call widgets material i1 gradient
qs ipc -p widgets-system call widgets colorMode i1 widget
qs ipc -p widgets-system call widgets materialList
```

### Раскладка (пока в памяти)

`LayoutStore` хранит экземпляры по имени экрана (`uid`, `id`, `col/row`,
`cols/rows`, `settings`). При первом появлении экрана в него раскладываются
встроенные виджеты. После перезапуска раскладка создаётся заново — это
**этап 4** (файл `~/.local/state/quickshell/widgets/layout.json`, миграция при
смене сетки, лоток).

## Встроенные виджеты

`widgets-system/builtin-widgets/`:

- `my.clock` — часы, `ctx.settings` (24 ч, секунды), диапазон размеров;
- `my.note` — заметка, строковая/enum-настройка, кликабельность;
- `my.color` — статичный цветной блок, `min == max` (без ресайза);
- `my.allowed` — только `size.allowed`;
- `my.palette` — собственная палитра в манифесте и режим `widget`;
- `my.switch` — минимальный переключатель с `bool`-настройкой и
  `ctx.setSetting()`.

## Конфиг

Путь: `$XDG_CONFIG_HOME/quickshell/widgets/config.json`
(по умолчанию `~/.config/quickshell/widgets/config.json`). Файла может не
быть — действуют значения по умолчанию. Образец: `config.example.json`.

```json
{
  "grid": {
    "cellTargetMm": 16,
    "outerMarginMm": 6,
    "gapRatio": 0.12,
    "minCols": 4,
    "maxCols": 24,
    "dpiOverride": 0,
    "showGrid": true,
    "reserved": { "top": 0, "right": 0, "bottom": 0, "left": 0 }
  },
  "widgets": { "extraPaths": [] },
  "theme": "dark",
  "wallpaper": "",
  "defaults": { "material": "glass", "colorMode": "accent" }
}
```

`showGrid`, `theme` и `wallpaper` перечитываются на лету.

### Про плотность

На Wayland/Qt `ShellScreen.logicalPixelDensity` — это фактически 96 dpi
(3.78 px/мм), а `physicalPixelDensity` уже учитывает scale и даёт логические
пиксели на миллиметр (для eDP 1920×1200 при 300×190 мм — 6.36 px/мм). Для
одинакового физического размера клетки `GridMetrics` берёт
`physicalPixelDensity`, а `logicalPixelDensity` — как запасной вариант. Если
обе величины вне разумных пределов — фолбэк на 96 dpi / dpr. `dpiOverride`
переопределяет всё.

## Структура

```
widgets-system/
  shell.qml                     точка входа, Variants по экранам
  core/
    Config.qml                  singleton конфига (XDG, JsonAdapter)
    Theme.qml                   палитра shell (пока базовая M3)
    GridMetrics.qml             расчёт сетки одного экрана
    WidgetRegistry.qml          поиск, валидация, наблюдение за файлами
    LayoutStore.qml             экземпляры и настройки (пока в памяти)
    WidgetContext.qml           объект ctx для виджета
    MaterialRegistry.qml        поиск материалов и их горячая перезагрузка
    Wallpaper.qml               источник обоев для glass
    WidgetIpc.qml               IPC-команды для проверки состояния
  desktop/
    DesktopLayer.qml            PanelWindow слоя рабочего стола
    WidgetHost.qml              подложка + Loader + ctx + ошибки
    WidgetStatusCard.qml        карточка ошибки/плейсхолдера
    GridOverlay.qml             отладочная сетка
    HostButton.qml              кнопка для карточек состояния
  builtin-widgets/              примеры (см. выше)
  materials/                    solid/transparent/gradient/grain/glass
  config.example.json
```

## Проверка этапов 1–3

- eDP 1920×1200 логических (2880×1800 физических, 300×190 мм, scale 1.5):
  сетка 16×9, клетка 104 px ≈ 16,3 мм. Headless 1280×720: 17×8, клетка 64 px.
- Смена разрешения/scale и отключение монитора пересчитывают сетку и удаляют
  слой без перезапуска.
- Слой сам встаёт ниже существующего бара; `GridMetrics` использует
  фактическую высоту окна.
- Клики вне карточек проходят до тестового слоя `Background`; клик по заметке
  доходит до её `MouseArea`. Маска состоит из 6 областей для 6 карточек.
- `my.clock`: правка `Main.qml` даёт `QML изменился: my.clock` и перезагрузку
  только часов (v0 → v1), остальные экземпляры не перезагружаются.
- `my.color`: синтаксическая ошибка QML → компактная карточка ошибки
  (`my.color: ошибка загрузки QML`), остальные виджеты работают; после
  исправления файла карточка исчезает без перезапуска.
- Удаление папки `my.allowed` → плейсхолдер с кнопкой удаления; возврат папки
  восстанавливает виджет.
- Папка `builtin-widgets/my.added`, созданная при работающем shell, появляется
  в списке (`доступно 6`) без перезапуска; удаление возвращает 5.
- Внешний путь: `QS_WIDGET_PATH=rt/test-widgets` добавляет `test.external` в
  список (`доступно 7`).
- `my.switch`: клик по виджету меняет `enabled` через `ctx.setSetting` и
  перерисовывает переключатель.

### Этап 3

- Встроенные материалы: 5 шт.; `materialList` показывает
  `gradient,grain,transparent,solid,glass`.
- `glass` размывает обои внутри карточек (скриншот
  `rt/widgets-stage3-final.png`); `transparent` убирает подложку, `grain`
  добавляет шум, `gradient` рисует переход.
- Смена материала `i7` (`glass` → `gradient` → `solid`) даёт только строку
  `[widgets/material] my.clock <- ...`, без `[widgets/host] загрузка`.
- `my.palette` в режиме `widget` показывает цвета своей палитры (оранжевый/
  бирюзовый/розовый) и подпись `widget`; `my.color` с `colorModes:["accent"]`
  остаётся в accent.
- Переключение глобального `theme` и `defaults.colorMode` меняет цвета без
  перезагрузки контента; `defaults.material` перезагружает только материалы.
- Пользовательский материал `my.neon` из тестового XDG-каталога появился в
  списке без перезапуска (после создания каталогов), применился к часам и
  перезагрузился при правке его `Material.qml`.

## Дальше

Этап 4: `LayoutStore` на диске (`~/.local/state/quickshell/widgets/layout.json`),
атомарная запись, миграция при смене сетки, лоток «Не помещается».
