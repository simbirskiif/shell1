# Как написать виджет для widgets-system

Виджет — обычная папка с `manifest.json` и QML. Shell находит её в одном из
путей поиска, валидирует манифест и создаёт экземпляры через `Loader`, передавая
корневому элементу объект `ctx`. Импортировать модули shell не нужно.

## 1. Структура папки

```
my.clock/
  manifest.json
  Main.qml          # entry, имя можно переопределить в манифесте
  preview.png       # необязательно (сейчас каталог использует живое превью)
  components/       # любые свои файлы и ассеты
```

Положите папку в один из путей (в порядке приоритета):

1. `widgets.extraPaths` в конфиге (можно добавить из пикера);
2. `$QS_WIDGET_PATH` (через `:`);
3. `~/.config/quickshell/widgets`;
4. `<shellDir>/builtin-widgets`;
5. `/usr/share/quickshell-widgets`.

Глубина поиска — 1–2 вложенные папки с манифестом. Новые папки подхватываются
без перезапуска.

## 2. manifest.json

```json
{
  "schema": 1,
  "id": "com.example.clock",
  "name": "Часы",
  "description": "Цифровые часы",
  "version": "1.0.0",
  "author": "me",
  "icon": "schedule",
  "entry": "Main.qml",
  "size": {
    "min": "1x2",
    "max": "2x4",
    "default": "1x2"
  },
  "materials": ["any"],
  "colorModes": ["accent", "widget"],
  "palette": {
    "light": {
      "surface": "#FFFBFE",
      "onSurface": "#1C1B1F",
      "primary": "#6750A4",
      "onPrimary": "#FFFFFF"
    },
    "dark": {
      "surface": "#1C1B1F",
      "onSurface": "#E6E1E5",
      "primary": "#D0BCFF",
      "onPrimary": "#381E72"
    }
  },
  "settings": [
    { "key": "format24", "type": "bool", "label": "24-часовой формат", "default": true },
    { "key": "city", "type": "string", "label": "Город", "default": "" },
    { "key": "style", "type": "enum", "label": "Стиль", "options": ["flat", "outline"], "default": "flat" }
  ]
}
```

Обязательны `schema` (1), `id` (обратный DNS), `name`, `size`. Неизвестные
поля игнорируются. `entry` по умолчанию `Main.qml` и должен существовать.

### Размеры

Формат — **строки × столбцы** (`1x2` = одна строка, две колонки; `2*4` тоже
допустимо). Два способа:

- диапазон: `min`, `max`, `default`;
- список: `allowed: ["1x2", "2x2"]` + `default`; список важнее диапазона.

`default` приводится к ближайшему допустимому. Если у виджета только один
размер (`min == max` или один элемент в `allowed`), хэндлов ресайза нет.

### Материалы и цвет

- `materials: ["any"]` — разрешены все материалы shell;
  иначе перечислите id (`"solid"`, `"glass"`, …). Это ограничение, а не выбор.
- `colorModes`: `"accent"` (палитра shell) и/или `"widget"` (своя `palette`).
- В `palette` можно указать только часть ролей — недостающие берутся из
  палитры shell.

### Настройки

Типы: `bool`, `string`, `int` (`min`/`max`), `real` (`min`/`max`), `enum`
(`options`), `color`. Shell рендерит их в попапе экземпляра и хранит значения
в раскладке.

## 3. QML-контракт

Корневой элемент `Main.qml` — `Item`, который объявляет `ctx`:

```qml
import QtQuick

Item {
    required property var ctx

    Text {
        anchors.centerIn: parent
        text: Qt.formatTime(clock.date, ctx.settings.format24 ? "HH:mm" : "hh:mm AP")
        color: ctx.colors.onSurface
        font.pixelSize: ctx.dp * 28
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
}
```

Shell сам задаёт размер корневого элемента; не выставляйте собственные
`width`/`height` и не рисуйте фон на всю площадь — подложку рисует материал
shell. Внутренние плашки можно.

### ctx

| Поле | Значение |
| --- | --- |
| `colors` | Роли Material: `surface`, `onSurface`, `surfaceVariant`, `onSurfaceVariant`, `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`, `secondary`, `onSecondary`, `tertiary`, `outline`, `error` |
| `colorMode` | `"accent"` или `"widget"` |
| `isDark` | Тёмная схема |
| `rows`, `cols` | Текущий размер в клетках |
| `width`, `height` | Размер в логических px |
| `cell` | Размер клетки в px |
| `dp` | px на 1dp (160 dpi) |
| `sizeClass` | `"compact"`, `"medium"`, `"large"` |
| `material` | id материала подложки |
| `editing` | Идёт редактирование |
| `preview` | Рендер в каталоге (не трогайте сеть/диск) |
| `screen` | Имя экрана |
| `settings` | Значения настроек экземпляра |
| `setSetting(key, value)` | Записать настройку (персистентно) |

Раскладку менять нельзя — только `setSetting`.

## 4. Лучшие практики

- Считайте размеры от `ctx.dp`/`ctx.cell`, а не в фиксированных px.
- В `ctx.preview === true` не запускайте сеть, процессы и чтение файлов;
  используйте демо-данные.
- В `ctx.editing === true` отключайте тяжёлые анимации и прямой интерактив:
  ввод перехватывает shell.
- Не блокируйте UI-поток; для процессов — `Process`, для файлов — `FileView`.
- Не создавайте таймеры без остановки; для часов используйте `SystemClock`.
- Не задавайте собственный фон на всю карточку — материал и скругление
  задаёт shell.
- Ошибки QML локализуются в карточке виджета; пишите осмысленные сообщения
  в лог через `console.error`.
- Проверка: `qs -p widgets-system`, горячая правка QML; см. README.

## 5. Материалы

Материал — папка в `materials/`:

```
materials/my.material/
  meta.json       # { "id", "name", "description" }
  Material.qml    # Item с контрактом ниже
  *.frag          # необязательно; собирается в *.frag.qsb
```

`Material.qml` должен объявить:

```qml
Item {
    property var colors: ({})
    property real radius: 0
    property var size: Qt.size(0, 0)
    property string wallpaperSource: ""
    property bool editing: false
    property real offsetX: 0
    property real offsetY: 0
    property real screenWidth: 0
    property real screenHeight: 0
    // ... отрисовка подложки
}
```

Шейдеры: `./tools/build-shaders.sh` (qsb, `--qt6`); готовые `.frag.qsb`
коммитятся. Пользовательские материалы лежат в
`~/.config/quickshell/widgets/materials` и обновляются без перезапуска.

## 6. Примеры

`builtin-widgets/`:

- `my.clock` — часы, настройки, диапазон размеров;
- `my.note` — строка/enum, клики;
- `my.color` — фиксированный размер;
- `my.allowed` — только `size.allowed`;
- `my.palette` — своя палитра;
- `my.switch` — bool-настройка и `ctx.setSetting`.
