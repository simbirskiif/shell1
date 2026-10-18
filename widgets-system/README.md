# Система виджетов рабочего стола для Quickshell

Отдельная конфигурация Quickshell: слой рабочего стола с сеткой, на которую
позже добавляются виджеты. ТЗ — `ТЗ система виджетов рабочего стола для
Quickshell.md` (в загрузках пользователя).

Реализация идёт по этапам из раздела 12 ТЗ. Сейчас готов **этап 1**.

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

Запущенную конфигурацию можно погасить через IPC:

```sh
XDG_RUNTIME_DIR=$PWD/rt/runtime qs kill -p widgets-system
```

## Что уже работает (этап 1)

- `Variants` по `Quickshell.screens`: по одному `DesktopLayer` на экран,
  подключение/отключение мониторов и смена геометрии обрабатываются без
  перезапуска.
- `DesktopLayer` — `PanelWindow` на слое `Bottom`, `exclusionMode: Normal`,
  `exclusiveZone: 0`. Композитор сам ужимает поверхность под панели других
  клиентов; сетка считается уже внутри фактического окна слоя.
- `GridMetrics` — расчёт клетки под экран/DPI по разделу 5 ТЗ: целевая клетка
  16 мм, gap 12 %, min/max столбцов, центрирование, выравнивание начала сетки
  на физические пиксели через `dpr`.
- Отладочная сетка с точками в центрах клеток и плашкой параметров.
- Пустая маска ввода: пока виджетов нет, клики проходят в окна под слоем.

### Про плотность

На Wayland/Qt `ShellScreen.logicalPixelDensity` — это фактически 96 dpi
(3.78 px/мм), а `physicalPixelDensity` уже учитывает scale и даёт логические
пиксели на миллиметр (для eDP 1920×1200 при 300×190 мм — 6.36 px/мм). Для
одинакового физического размера клетки `GridMetrics` берёт
`physicalPixelDensity`, а `logicalPixelDensity` использует как запасной
вариант. Если обе величины вне разумных пределов — фолбэк на 96 dpi / dpr.
`dpiOverride` в конфиге переопределяет всё.

## Конфиг

Путь: `$XDG_CONFIG_HOME/quickshell/widgets/config.json`
(по умолчанию `~/.config/quickshell/widgets/config.json`). Файла может не
быть — тогда действуют значения по умолчанию. Образец:
`config.example.json`.

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
  "defaults": { "material": "solid", "colorMode": "accent" }
}
```

`showGrid` можно переключить правкой файла — конфиг перечитывается на лету.

## Структура

```
widgets-system/
  shell.qml                  точка входа, Variants по экранам
  core/
    Config.qml               singleton конфига (XDG, JsonAdapter)
    GridMetrics.qml          расчёт сетки одного экрана
  desktop/
    DesktopLayer.qml         PanelWindow слоя рабочего стола
    GridOverlay.qml          отладочная сетка
  config.example.json
```

## Проверка этапа 1

- На eDP (1920×1200 логических, scale 1.5): сетка 16×9, клетка 104 px =
  16.4 мм; на подключённом headless-экране 1280×720: 17×8, клетка 64 px.
- Смена режима headless-экрана (`1024×768`, `scale 1`) и обратно
  пересчитывает сетку без перезапуска.
- Отключение headless-экрана удаляет его слой; основной экран продолжает
  работать.
- Пустая маска: `WAYLAND_DEBUG=1` показывает `wl_surface.set_input_region` с
  пустым `wl_region`; синтетический клик через
  `zwlr_virtual_pointer_manager_v1` доходит до тестового слоя `Background`
  под нашим слоем. При временно выставленной маске на весь экран клик не
  доходит.

## Дальше

Этап 2: `WidgetRegistry`, валидация `manifest.json`, `WidgetHost`, `Loader`,
инъекция `ctx`, размеры в клетках.
