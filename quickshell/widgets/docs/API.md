# API виджетов Quickshell

Единый справочник по виджетам этой оболочки: контракт пакета, `manifest.json`,
объект `ctx`, материалы, раскладка, IPC, настройки и примеры.

Актуально для текущей оболочки в `/home/adm_a/shell/quickshell`
(Quickshell 0.3.2, Qt 6.12). Это не отдельная программа: виджеты работают
внутри основной оболочки и запускаются вместе с ней.

---

## 1. Быстрый старт

### 1.1. Запуск оболочки

```sh
qs
# или явно:
qs -p /home/adm_a/shell/quickshell
```

Отдельного `qs -p widgets-system` больше нет.

### 1.2. Куда положить виджет

Создайте папку на глубине 1–2 от одного из путей поиска:

```text
~/.config/quickshell/widgets/my.hello/
├── manifest.json
└── Main.qml
```

`my.hello` — имя папки; идентификатор виджета задаётся в `manifest.json` и
не обязан совпадать с именем папки.

Пути поиска в порядке приоритета:

1. `widgets.extraPaths` из `config.json`;
2. `$QS_WIDGET_PATH` (несколько путей через `:`);
3. `$XDG_CONFIG_HOME/quickshell/widgets` (обычно
   `~/.config/quickshell/widgets`);
4. `<shellDir>/builtin-widgets`, то есть
   `/home/adm_a/shell/quickshell/builtin-widgets`;
5. `/usr/share/quickshell-widgets`.

Глубина: папка с `manifest.json` может быть **самим корнем поиска** (глубина
0), лежать на глубине 1 или 2. То есть `extraPaths` может указывать как на
общий каталог виджетов, так и непосредственно на папку с манифестом.
Символические ссылки не разворачиваются — циклов нет.

### 1.3. Минимальный манифест

`manifest.json`:

```json
{
  "schema": 1,
  "id": "com.example.hello",
  "name": "Привет",
  "description": "Минимальный виджет",
  "version": "1.0.0",
  "author": "you",
  "entry": "Main.qml",
  "size": {
    "min": "1x1",
    "max": "2x2",
    "default": "1x1"
  },
  "settings": []
}
```

`Main.qml`:

```qml
import QtQuick

Item {
    required property var ctx

    Text {
        anchors.centerIn: parent
        text: "Привет"
        color: ctx.colors.onSurface
        font.family: ctx.fontFamily
        font.pixelSize: Math.max(12, Math.round(ctx.dp * 16))
    }
}
```

После создания папки:

```sh
# если нужно — пересканировать каталоги
qs ipc -p /home/adm_a/shell/quickshell call widgets rescan

# открыть каталог и добавить виджет
qs ipc -p /home/adm_a/shell/quickshell call widgets picker
```

Обычно достаточно просто сохранить файлы — реестр подхватит новую папку сам.

---

## 2. Структура пакета виджета

```text
my.widget/
├── manifest.json       # обязателен
├── Main.qml            # entry; имя можно задать в manifest.entry
├── components/         # любые ваши QML-файлы
├── assets/             # картинки, иконки, звуки
└── README.md           # необязательно
```

Правила:

- `manifest.json` обязан быть валидным JSON-объектом.
- `entry` — относительный путь внутри папки. Абсолютные пути, `..` и
  обратные слэши запрещены.
- В `entry` должен существовать QML-файл; по умолчанию ищется `Main.qml`.
- `preview.png` сейчас не используется: каталог строит живое превью.
- Ассеты подключайте относительно QML, например
  `source: Qt.resolvedUrl("assets/icon.png")`.
- Не задавайте размеры корневого элемента и не рисуйте фон на всю карточку:
  размер задаёт shell, фон и скругление — материал.

### 2.1. Что можно импортировать

Обычно достаточно:

```qml
import QtQuick
import Quickshell          // SystemClock, Process, FileView и т.п.
```

Не полагайтесь на внутренние синглтоны оболочки (`Theme`,
`LayoutStore`, `EditorState`): переносимый виджет должен работать только
через `ctx`. Если нужен системный шрифт — используйте `ctx.fontFamily`.
Если нужны системные цвета — `ctx.colors`.

---

## 3. manifest.json

### 3.1. Полный пример

```json
{
  "schema": 1,
  "id": "com.example.clock",
  "name": "Часы",
  "description": "Цифровые часы с датой",
  "version": "1.0.0",
  "author": "you",
  "icon": "schedule",
  "entry": "Main.qml",
  "size": {
    "min": "1x2",
    "max": "2x4",
    "default": "1x2"
  },
  "settings": [
    {
      "key": "format24",
      "type": "bool",
      "label": "24-часовой формат",
      "default": true
    },
    {
      "key": "seconds",
      "type": "bool",
      "label": "Показывать секунды",
      "default": false
    },
    {
      "key": "city",
      "type": "string",
      "label": "Город",
      "default": ""
    }
  ]
}
```

### 3.2. Поля

| Поле | Обяз. | Тип | Смысл |
|---|---|---|---|
| `schema` | да | int | Должно быть `1`. |
| `id` | да | string | Обратный DNS: `com.example.clock`. Только `A-Z a-z 0-9 . _ -`, первый символ — буква/цифра, точка обязательна. |
| `name` | да | string | Отображаемое имя. |
| `description` | нет | string | Описание в каталоге. |
| `version` | нет | string | Версия автора. |
| `author` | нет | string | Автор. |
| `icon` | нет | string | Иконка/имя иконки; по умолчанию `widgets`. |
| `entry` | нет | string | Путь к QML от папки; по умолчанию `Main.qml`. |
| `size` | да | object | Допустимые размеры. |
| `settings` | нет | array | Пользовательские настройки. |

Неизвестные поля игнорируются. Ошибки валидации попадают в
`WidgetRegistry.problems`, конфликты id — в `WidgetRegistry.conflicts`.

Важно: поля `materials`, `colorModes` и `palette` **больше не управляют
виджетом**. Материал и палитру назначает система. Старые манифесты с этими
полями читаются, но значения игнорируются.

### 3.3. Размеры

Формат — **строки × столбцы** (`YxX` или `Y*X`):

- `"1x2"` — 1 строка, 2 столбца;
- `"2x4"` — 2 строки, 4 столбца.

Два взаимоисключающих способа:

**Диапазон:**

```json
"size": {
  "min": "1x2",
  "max": "2x4",
  "default": "1x2"
}
```

**Список:**

```json
"size": {
  "allowed": ["1x2", "2x2", "2x4"],
  "default": "2x2"
}
```

`allowed` имеет приоритет над `min`/`max`. `default` приводится к
ближайшему допустимому размеру. Если допустим только один размер,
хэндлов изменения размера нет.

### 3.4. settings

Типы:

| `type` | `default` | Доп. поля | UI |
|---|---|---|---|
| `bool` | `false` | — | переключатель |
| `string` | `""` | — | текстовое поле |
| `int` | `0` | `min`, `max` | текстовое поле с числом |
| `real` | `0` | `min`, `max` | текстовое поле с числом |
| `enum` | первый `options` | `options` (string/number) | кнопки |
| `color` | `"#6750A4"` | — | текстовое поле с цветом |

`key` должен быть непустой строкой; дубликаты игнорируются. `label`
необязателен, по умолчанию равен `key`. Некорректные элементы пропускаются;
если не прошёл ни один — в лог пишется предупреждение.

Значения сохраняются в раскладке экземпляра. `reset` в редакторе возвращает
значения `default`.

---

## 4. Контракт `ctx`

Корень `Main.qml` обязан быть `Item` и объявить:

```qml
required property var ctx
```

Shell создаёт `WidgetContext` на каждый экземпляр и передаёт его через
`Loader.setSource(url, { ctx: ... })`.

### 4.1. Поля

| Поле | Тип | Описание |
|---|---|---|
| `colors` | object | Палитра Material-ролей от системы. |
| `colorMode` | string | `"accent"` или `"neutral"`. |
| `material` | string | id текущего материала, например `"glass"`. |
| `materialDim` | real | Затемнение материала, `0.10…0.95`. |
| `isDark` | bool | Тёмная схема. |
| `rows`, `cols` | int | Текущий размер в клетках; во время drag/resize — live-размер. |
| `width`, `height` | int | Размер карточки в логических px; во время drag/resize — live-размер. |
| `cell` | int | Размер клетки в px. |
| `dp` | real | px на 1dp при 160 dpi. |
| `sizeClass` | string | `"compact"` / `"medium"` / `"large"`. |
| `editing` | bool | Открыт режим редактирования. |
| `preview` | bool | Это превью в каталоге. |
| `screen` | string | Имя экрана. |
| `fontFamily` | string | Шрифт оболочки. |
| `settings` | object | Значения настроек экземпляра. |
| `setSetting(key, value)` | function | Записать настройку. |

`sizeClass` считается по меньшей стороне:

- `<= 1` клетки — `compact`;
- `>= 3` — `large`;
- иначе `medium`.

`width`/`height` — размер **всей карточки**, включая внутренние отступы.
Контентный `Loader` сейчас кладётся с отступом `Theme.quickPadding` (12 px)
внутрь карточки. То есть фактическая ширина корневого Item виджета примерно
`ctx.width - 24`. Не рассчитывайте на точное совпадение с `ctx.width`;
используйте `parent.width`/`parent.height`, если нужен реальный размер.

### 4.2. `ctx.colors`

Сейчас доступны роли:

```text
surface
onSurface
surfaceVariant
onSurfaceVariant
primary
onPrimary
primaryContainer
onPrimaryContainer
secondary
onSecondary
tertiary
outline
error
```

Палитру назначает система:

- `accent` — акцент Wal/оболочки;
- `neutral` — нейтральная системная палитра.

Виджет **не объявляет** свою палитру в манифесте. Если автору нужны
собственные цвета, он может просто не использовать `ctx.colors`.

### 4.3. Настройки

```qml
Text {
    text: ctx.settings.format24 ? "24h" : "12h"
}

MouseArea {
    anchors.fill: parent
    onClicked: ctx.setSetting("format24", !ctx.settings.format24)
}
```

`ctx.setSetting` — единственный разрешённый способ менять настройки.
Геометрию, позицию и раскладку виджет менять не может.

Значения по умолчанию и текущие переопределения склеиваются shell'ом;
`ctx.settings` всегда содержит полный набор ключей из `manifest.settings`.

### 4.4. Превью и редактор

- `ctx.preview === true` — виджет рендерится в каталоге.
  Не запускайте сеть, процессы и чтение файлов; используйте демо-данные.
  Настройки в превью — дефолтные.
- `ctx.editing === true` — открыт редактор. Ввод перехватывает shell,
  поэтому тяжёлые анимации и прямой интерактив лучше отключать.

---

## 5. Материалы

Материал — подложка карточки: цвет/стекло, скругление, тень, шейдер.
Содержимое виджета рисуется поверх.

### 5.1. Встроенные материалы

```text
solid        — сплошной
transparent  — без подложки
gradient     — градиент системной палитры
grain        — сплошной + процедурное зерно (шейдер)
glass        — размытие обоев, тонировка (шейдер)
liquid       — размытие, преломление, дисперсия, rim (шейдер)
```

Отдельный `blur.frag` лежит в `materials/liquid` как утилитарный шейдер для
пользовательских материалов. Он не является отдельным стилем.

### 5.2. Пользовательские материалы

Пути поиска:

1. `$QS_MATERIAL_PATH` (через `:`);
2. `$XDG_CONFIG_HOME/quickshell/widgets/materials`;
3. `<shellDir>/materials`.

Пользовательские материалы имеют приоритет над встроенными. Путь может
указывать на каталог материалов или на саму папку материала (глубина 0–2).

Структура:

```text
materials/my.material/
├── meta.json
├── Material.qml
└── my.frag          # необязательно
```

`meta.json`:

```json
{
  "id": "my.material",
  "name": "Мой материал",
  "description": "Короткое описание"
}
```

`id` необязателен: если пуст, берётся имя папки. Допустимы
`A-Z a-z 0-9 . _ -`.

### 5.3. Контракт Material.qml

`Material.qml` — `Item`, который получает свойства от shell:

```qml
import QtQuick

Item {
    id: root
    property var colors: ({})          // палитра
    property real radius: 0             // радиус скругления
    property real dim: 0.60             // системное затемнение
    property var size: Qt.size(0, 0)    // размер карточки
    property string wallpaperSource: "" // file:// обоев
    property bool editing: false
    property real offsetX: 0            // экранные координаты
    property real offsetY: 0
    property real localX: 0             // координаты слоя
    property real localY: 0
    property real screenWidth: 0
    property real screenHeight: 0
    property var widgetsBackdrop: null  // другие виджеты при drag
}
```

`widgetsBackdrop` — системная текстура для перетаскивания; большинству
материалов достаточно её игнорировать. `localX/localY` — координаты
относительно слоя виджетов, `offsetX/offsetY` — экранные координаты
(с учётом панели сверху).

Материал сам отвечает за отрисовку подложки в своих границах. Контент
виджета рисуется поверх и уже обрезан по карточке.

Пример сплошного материала:

```qml
import QtQuick

Item {
    id: root
    property var colors: ({})
    property real radius: 0
    property real dim: 0.60
    property var size: Qt.size(0, 0)
    property string wallpaperSource: ""
    property bool editing: false
    property real offsetX: 0
    property real offsetY: 0
    property real localX: 0
    property real localY: 0
    property real screenWidth: 0
    property real screenHeight: 0
    property var widgetsBackdrop: null

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.colors.surface || "#151519"
    }
}
```


### 5.4. Шейдерный материал

1. Напишите `m.frag` в GLSL 440.
2. Соберите:

```sh
qsb --qt6 -o m.frag.qsb m.frag
```

3. Подключите в `Material.qml`:

```qml
ShaderEffect {
    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl("m.frag.qsb")
    property variant source: ...
}
```

Готовые примеры: `quickshell/materials/glass`, `grain`, `liquid`.

Для пользовательских шейдеров удобно смотреть на `liquid/Material.qml`:
там есть `ShaderEffectSource` с `sourceRect` и `hideSource`, который
вырезает нужный кусок обоев.

Шейдеры в `quickshell/materials/*/*.frag` пересобираются скриптом:

```sh
quickshell/widgets/tools/build-shaders.sh
```

Важно: реестр материалов следит за `meta.json`, папкой и `Material.qml`,
но не за `.frag`/`.qsb`. После пересборки QSB перезапустите оболочку или
перезагрузите материал (например, `touch Material.qml`), иначе может
использоваться старый скомпилированный шейдер из кеша.

### 5.5. Параметры материала

- `dim` приходит от системы; глобальный слайдер и переопределение
  экземпляра находятся в настройках.
- `radius` сейчас равен `Theme.quickRadius` (18 px) и одинаков для всех
  виджетов; не задавайте свой радиус в контенте.
- `colors` — системная палитра; не смешивайте её с `manifest.palette`
  (последний игнорируется).

---

## 6. Раскладка и состояние

### 6.1. Где хранится

```text
$XDG_STATE_HOME/quickshell/widgets/layout.json
# обычно:
~/.local/state/quickshell/widgets/layout.json
```

Схема:

```json
{
  "schema": 1,
  "defaults": {
    "material": "glass",
    "colorMode": "accent",
    "dim": 0.6
  },
  "screens": {
    "eDP-1": {
      "signature": "16x9",
      "grid": { "cols": 16, "rows": 9 },
      "widgets": [
        {
          "uid": "i1",
          "id": "com.example.clock",
          "name": "Часы",
          "col": 2,
          "row": 2,
          "cols": 2,
          "rows": 1,
          "material": null,
          "colorMode": null,
          "dim": null,
          "settings": { "format24": true }
        }
      ],
      "tray": [],
      "signatures": {}
    }
  }
}
```

- `material`, `colorMode`, `dim` со значением `null` означают «как в
  глобальных настройках».
- `settings` — значения экземпляра.
- `uid` — внутренний стабильный id экземпляра, не путать с `manifest.id`.

### 6.2. Сетка

- Целевая клетка — 16 мм.
- Промежуток — 12 % клетки.
- Сетка центрируется в доступной области; количество столбцов ограничено
  `minCols`/`maxCols`.
- Для каждого экрана хранится своя сигнатура `cols x rows`; при смене
  сигнатуры позиции масштабируются, размеры нормализуются, не поместившиеся
  экземпляры уходят в tray.
- Раскладка сохраняется с задержкой (debounce), атомарно.

---

## 7. Редактор и каталог

- Вход: **ПКМ по рабочему столу → «Изменить расположение»**.
- ПКМ по виджету: **«Параметры виджета…»**.
- ПКМ по пустому месту: «Добавить виджет…», «Параметры виджетов…»,
  «Изменить расположение».
- В редакторе:
  - карточка уменьшается до 95 %;
  - круглые ⚙/✕ выходят за верхнюю правую границу;
  - выделение — зелёный скруглённый контур;
  - тянуть за контур — resize, за середину — drag;
  - перетаскиваемая карточка поднимается над соседями и призраком;
  - glass/liquid при drag видят соседние виджеты и их рамки через шейдер;
  - «Готово» сохраняет, «Отмена» откатывает сессию, Esc работает как
    «Готово» (если не открыта панель).
- Каталог открывается справа на всю высоту; добавление — тапом или
  drag-and-drop.
- Настройки экземпляра и глобальные параметры — правые панели на всю высоту.

---

## 8. IPC

Цель: `widgets`.

```sh
qs ipc -p /home/adm_a/shell/quickshell call widgets <function> [args...]
```

### 8.1. Команды

| Команда | Аргументы | Что делает |
|---|---|---|
| `state` | — | Полное состояние раскладки и редактора. |
| `edit` | `toggle`/`on`/`off`/`cancel`/`undo`/`redo` | Управление редактором. |
| `addPath` | путь | Добавить путь поиска виджетов в `config.json`. |
| `picker` | — | Открыть/закрыть каталог. |
| `settings` | `uid` | Открыть настройки экземпляра. |
| `globals` | — | Открыть глобальные параметры. |
| `defaults` | `material` `colorMode` | Задать глобальные значения. |
| `dim` | `0.10…0.95` | Глобальное затемнение. |
| `geometry` | `uid col row cols rows` | Задать геометрию без открытия редактора. |
| `dimFor` | `uid value` | Затемнение экземпляра; `-1` сбрасывает. |
| `remove` | `uid` | Удалить экземпляр (с undo-снимком). |
| `material` | `uid materialId` | Материал экземпляра; пустая строка — default. |
| `colorMode` | `uid accent\|neutral` | Палитра экземпляра. |
| `materialList` | — | Список материалов. |
| `rescan` | — | Пересканировать виджеты и материалы. |

### 8.2. Примеры

```sh
qs ipc -p /home/adm_a/shell/quickshell call widgets state
qs ipc -p /home/adm_a/shell/quickshell call widgets edit toggle
qs ipc -p /home/adm_a/shell/quickshell call widgets material i1 liquid
qs ipc -p /home/adm_a/shell/quickshell call widgets colorMode i1 neutral
qs ipc -p /home/adm_a/shell/quickshell call widgets dimFor i1 0.35
qs ipc -p /home/adm_a/shell/quickshell call widgets dimFor i1 -1
qs ipc -p /home/adm_a/shell/quickshell call widgets geometry i1 0 0 2 2
```

`state` выводит экраны, uid, id, позиции, размеры, материал, цвет, dim,
редактор, undo/redo, глобальные defaults.

---

## 9. config.json

Путь:

```text
$XDG_CONFIG_HOME/quickshell/widgets/config.json
# обычно:
~/.config/quickshell/widgets/config.json
```

Пример:

```json
{
  "grid": {
    "cellTargetMm": 16,
    "outerMarginMm": 6,
    "gapRatio": 0.12,
    "minCols": 4,
    "maxCols": 24,
    "dpiOverride": 0,
    "showGrid": false,
    "reserved": { "top": 0, "right": 0, "bottom": 0, "left": 0 }
  },
  "widgets": {
    "extraPaths": ["/home/me/my-widgets"]
  },
  "wallpaper": "",
  "defaults": {
    "material": "glass",
    "colorMode": "accent",
    "dim": 0.6
  }
}
```

- `grid.reserved` — зарезервированные области в логических px.
- `grid.dpiOverride` — px/мм; `0` — авто.
- `grid.showGrid` — отладочная сетка.
- `wallpaper` — путь/URL для glass; пусто — спросить hyprpaper.
- `defaults` — глобальные материал/цвет/затемнение.
- `extraPaths` — пользовательские каталоги виджетов.

Файл читается с `watchChanges`; изменения подхватываются без перезапуска.

Глобальные значения также можно менять из UI «Параметры виджетов» и через IPC
`defaults`/`dim`.

---

## 10. Примеры

### 10.1. Часы с настройками

`manifest.json`:

```json
{
  "schema": 1,
  "id": "com.example.clock",
  "name": "Часы",
  "entry": "Main.qml",
  "size": { "min": "1x2", "max": "2x4", "default": "1x2" },
  "settings": [
    { "key": "format24", "type": "bool", "label": "24-часовой формат", "default": true },
    { "key": "seconds", "type": "bool", "label": "Секунды", "default": false }
  ]
}
```

`Main.qml`:

```qml
import QtQuick
import Quickshell

Item {
    required property var ctx

    SystemClock {
        id: clock
        precision: ctx.settings.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.round(ctx.dp * 2)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date,
                                ctx.settings.format24 ? "HH:mm" : "hh:mm AP")
            color: ctx.colors.onSurface
            font.family: ctx.fontFamily
            font.pixelSize: Math.max(14, Math.round(ctx.dp
                * (ctx.sizeClass === "compact" ? 26 : 42)))
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "ddd, d MMM")
            color: ctx.colors.onSurfaceVariant
            font.family: ctx.fontFamily
            font.pixelSize: Math.max(10, Math.round(ctx.dp * 11))
        }
    }
}
```

### 10.2. Заметка с enum/string

```json
{
  "schema": 1,
  "id": "com.example.note",
  "name": "Заметка",
  "entry": "Main.qml",
  "size": { "min": "2x2", "max": "4x4", "default": "2x2" },
  "settings": [
    { "key": "text", "type": "string", "label": "Текст", "default": "Заметка" },
    { "key": "align", "type": "enum", "label": "Выравнивание",
      "options": ["left", "center"], "default": "left" }
  ]
}
```

```qml
import QtQuick

Item {
    required property var ctx

    Text {
        anchors.fill: parent
        anchors.margins: Math.round(ctx.dp * 8)
        text: ctx.settings.text
        color: ctx.colors.onSurface
        font.family: ctx.fontFamily
        font.pixelSize: Math.max(11, Math.round(ctx.dp * 13))
        wrapMode: Text.WordWrap
        horizontalAlignment: ctx.settings.align === "center"
                             ? Text.AlignHCenter : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
    }
}
```

### 10.3. Только допустимые размеры

```json
"size": {
  "allowed": ["1x2", "2x2", "2x4"],
  "default": "2x2"
}
```

```qml
Text {
    anchors.centerIn: parent
    text: ctx.cols + " × " + ctx.rows
    color: ctx.colors.onSurface
    font.family: ctx.fontFamily
    font.pixelSize: Math.max(11, Math.round(ctx.dp * 14))
}
```

### 10.4. Виджет, игнорирующий системную палитру

Это разрешено: `ctx.colors` — рекомендация системы, а не принудительный цвет.

```qml
import QtQuick

Item {
    required property var ctx

    Rectangle {
        anchors.fill: parent
        radius: Math.round(ctx.cell * 0.16)
        color: "#3b2a55"
    }

    Text {
        anchors.centerIn: parent
        text: "Свои цвета"
        color: "#f5e9ff"
        font.family: ctx.fontFamily
    }
}
```

### 10.5. Свой материал

`widgets/materials/my.solid/meta.json`:

```json
{ "id": "my.solid", "name": "Мой сплошной", "description": "Пример" }
```

`Material.qml`:

```qml
import QtQuick

Item {
    id: root
    property var colors: ({})
    property real radius: 0
    property real dim: 0.60
    property var size: Qt.size(0, 0)
    property string wallpaperSource: ""
    property bool editing: false
    property real offsetX: 0
    property real offsetY: 0
    property real localX: 0
    property real localY: 0
    property real screenWidth: 0
    property real screenHeight: 0
    property var widgetsBackdrop: null

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.colors.surface || "#151519"
    }
}
```

Положить в `~/.config/quickshell/widgets/materials/my.solid/`, затем
`qs ipc ... rescan`; материал появится в списке.

### 10.6. Свой шейдерный материал

```sh
mkdir -p ~/.config/quickshell/widgets/materials/my.shader
```

`m.frag`:

```glsl
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
} ubuf;

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * ubuf.size;
    float d = length(max(abs(p) - ubuf.size * 0.5 + ubuf.radius, 0.0))
              + min(max(abs(p).x - ubuf.size.x * 0.5 + ubuf.radius,
                        abs(p).y - ubuf.size.y * 0.5 + ubuf.radius), 0.0)
              - ubuf.radius;
    if (d > 0.0) discard;
    fragColor = vec4(0.2, 0.5, 0.8, 1.0) * ubuf.qt_Opacity;
}
```

Сборка:

```sh
qsb --qt6 -o m.frag.qsb m.frag
```

`Material.qml`:

```qml
import QtQuick

Item {
    id: root
    property var colors: ({})
    property real radius: 0
    property real dim: 0.60
    property var size: Qt.size(0, 0)
    property string wallpaperSource: ""
    property bool editing: false
    property real offsetX: 0
    property real offsetY: 0
    property real localX: 0
    property real localY: 0
    property real screenWidth: 0
    property real screenHeight: 0
    property var widgetsBackdrop: null

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("m.frag.qsb")
        property vector2d size: Qt.vector2d(Math.max(1, root.width),
                                            Math.max(1, root.height))
        property real radius: root.radius
    }
}
```

Для использования обоев смотрите `materials/glass/Material.qml`:
`Image` + `ShaderEffectSource` с `sourceRect` по `offsetX/offsetY`.

---

## 11. Горячая перезагрузка

- Изменение `.qml` внутри папки виджета → перезагружаются только его
  экземпляры.
- Изменение `manifest.json` → пересканирование реестра; если fingerprint
  изменился, экземпляры виджета перезагружаются.
- Добавление/удаление папки → пересканирование.
- Удаление папки установленного виджета → плейсхолдер «Виджет недоступен»
  с кнопкой удаления.
- Ошибка QML → карточка ошибки в этой карточке; соседние виджеты живы.
- Материалы: `meta.json`/`Material.qml` перезагружаются; `.frag`/`.qsb`
  требуют пересборки и перезапуска/перезагрузки материала (см. 5.4).
- Для принудительного пересканирования:
  `qs ipc ... call widgets rescan`.

---

## 12. Ошибки и отладка

| Симптом | Причина / что делать |
|---|---|
| Виджет не появился | Нет `manifest.json`, неверный JSON, глубина > 2, неверный `size`, нет `entry`. |
| `problems`/конфликт id | Проверьте `id`: обратный DNS, уникальность. |
| `ctx` undefined | В корне нет `required property var ctx`. |
| Виджет нулевого размера | Вы задали `width`/`height` корню. Уберите. |
| Фон закрывает скругление | Не рисуйте фон на всю карточку; это делает материал. |
| Настройки не видны | Проверьте `settings`: `key`, `type`, `default`, `options`. |
| Нет resize | Размер фиксирован (`min == max` или один `allowed`). |
| Превью пустое/ошибка | Синтаксис QML; смотрите лог `quickshell`/`qs log`. |
| Палитра не такая | `manifest.palette` игнорируется; используйте `ctx.colors`. |
| Материал не появился | Нет `Material.qml`, неверный `meta.json`, глубина > 2. |
| Шейдер чёрный/пустой | Неверный `.qsb`, `fragmentShader` путь, старый кеш; пересоберите и перезапустите. |
| Асеты не найдены | Используйте `Qt.resolvedUrl("...")` относительно QML. |
| Настройки не сохраняются | Меняйте только через `ctx.setSetting`; не пишите layout вручную. |

Логи:

```sh
qs log
# или смотрите stderr процесса Quickshell
```

Полезные проверки:

```sh
qs ipc -p /home/adm_a/shell/quickshell call widgets state
qs ipc -p /home/adm_a/shell/quickshell call widgets materialList
qmllint -I . Main.qml
```

---

## 13. Чек-лист автора

- [ ] Папка на глубине 1–2 в пути поиска.
- [ ] `manifest.json` валиден, `schema: 1`, `id` уникален.
- [ ] `entry` существует и относителен.
- [ ] Корень — `Item` с `required property var ctx`.
- [ ] Нет собственных `width/height` корня и фона на всю карточку.
- [ ] Контент адаптируется к `ctx.rows/cols`, `ctx.sizeClass`, `ctx.dp`.
- [ ] `preview` не трогает сеть/диск/процессы.
- [ ] Настройки объявлены в `settings`, меняются через `ctx.setSetting`.
- [ ] Проверены все размеры из `size`.
- [ ] Проверены материалы: solid/transparent/gradient/grain/glass/liquid.
- [ ] Проверены accent/neutral и dim 0.10/0.95.
- [ ] `qmllint` без ошибок.
- [ ] Виджет протестирован в редакторе и в превью.
- [ ] Для шейдеров `.frag.qsb` собран и лежит рядом с Material.qml.

---

## 14. Безопасность

Виджет — это QML, который выполняется в процессе оболочки и имеет доступ к
`Process`, `FileView`, сети и файловой системе. Устанавливайте только
виджеты, которым доверяете. API не является sandbox'ом.

---

## 15. Связанные файлы

- `quickshell/widgets/docs/API.md` — этот справочник.
- `quickshell/widgets/README.md` — обзор системы и эксплуатация.
- `quickshell/widgets/docs/WIDGET_AUTHORING.md` — краткая инструкция автора.
- `quickshell/widgets/core/WidgetContext.qml` — живой контракт `ctx`.
- `quickshell/widgets/core/WidgetRegistry.qml` — валидация manifest.
- `quickshell/widgets/core/WidgetIpc.qml` — IPC.
- `quickshell/widgets/core/LayoutStore.qml` — раскладка и настройки.
- `quickshell/materials/` — примеры материалов.
- `quickshell/builtin-widgets/` — примеры виджетов.
