# Система виджетов рабочего стола (часть основной оболочки)

Модуль рабочего стола с виджетами в составе оболочки
`/home/adm_a/shell/quickshell`. Это не отдельная конфигурация Quickshell:
`DesktopLayer` и IPC `widgets` подключены прямо в `quickshell/shell.qml`,
поэтому виджеты запускаются и живут вместе с баром, уведомлениями и OSD.

Оформление берётся из общей среды: палитра — `singletons/Theme.qml` и
`Wal` (pywal), шрифты/радиусы/анимации — общий `Theme`. Отдельной темы у
виджетов нет.

## Запуск

```sh
qs                       # обычный запуск основной оболочки
# или явно:
qs -p /home/adm_a/shell/quickshell
```

После правки QML оболочка перезагружается целиком (как обычно); правка
QML установленного виджета перезагружает только его экземпляры.

Погасить/перезапустить — как обычно для этой оболочки. IPC модуля:

```sh
qs ipc -p /home/adm_a/shell/quickshell call widgets state
qs ipc -p /home/adm_a/shell/quickshell call widgets edit toggle
qs ipc -p /home/adm_a/shell/quickshell call widgets material i1 gradient
qs ipc -p /home/adm_a/shell/quickshell call widgets colorMode i1 widget
qs ipc -p /home/adm_a/shell/quickshell call widgets materialList
qs ipc -p /home/adm_a/shell/quickshell call widgets globals
qs ipc -p /home/adm_a/shell/quickshell call widgets defaults glass accent
qs ipc -p /home/adm_a/shell/quickshell call widgets addPath /path/to/widgets
```

## Что умеет

### Слой и сетка

- `Variants` по `Quickshell.screens`: по одному `DesktopLayer` на экран;
  подключение/отключение мониторов и смена геометрии — без перезапуска.
- `PanelWindow` на слое `Bottom`, `exclusionMode: Normal`,
  `exclusiveZone: 0`. Композитор ужимает поверхность под панели, сетка
  считается по фактическому размеру окна. В редакторе **то же самое окно**
  переходит в режим `Overlay` (фокус `OnDemand`, полная маска ввода), но сетка
  сохраняет размеры обычного слоя (`stableWidth/Height`), поэтому раскладка не
  меняется. Отдельного окна/слоя у редактора, меню и настроек нет.
- Область ввода покрывает весь рабочий стол: это единственный слой виджетов,
  поэтому ПКМ по пустому месту открывает контекстное меню, а не уходит в
  другое окно. Клики по окнам выше слоя не затрагиваются.
- `GridMetrics`: целевая клетка 16 мм, gap 12 %, min/max столбцов,
  центрирование, выравнивание по `dpr`. Отладочная сетка скрыта по умолчанию
  и в редакторе; `showGrid: true` включает её для отладки.

### Виджеты

- Поиск: `widgets.extraPaths` конфига (приоритет), `$QS_WIDGET_PATH`,
  `~/.config/quickshell/widgets`, `<shellDir>/builtin-widgets`,
  `/usr/share/quickshell-widgets`. Глубина 1–2, без симлинк-циклов.
- Валидация `manifest.json`: `schema`, обратный DNS `id`, `name`, `size`,
  существование `entry`; неизвестные поля игнорируются. Ошибки — в
  `WidgetRegistry.problems`, конфликты id — в `conflicts`.
- Размеры: диапазон или `allowed` (приоритет), `строки×столбцы`, `default`
  приводится к ближайшему допустимому.
- `WidgetHost`: подложка-материал, содержимое через `Loader.setSource(url,
  { ctx })`, локальные `display*`-геометрия и анимация 180 мс после
  drag/resize. Ошибка QML локализуется в карточке.
- `WidgetContext`: `colors`, `colorMode`, `isDark`, `rows/cols`,
  `width/height`, `cell`, `dp`, `sizeClass`, `material`, `editing`,
  `preview`, `screen`, `settings`, `setSetting()`.
- Настройки из `manifest.settings` (`bool/string/int/real/enum/color`) — в
  попапе ⚙; значения сохраняются в layout.
- Пропавший с диска виджет → плейсхолдер с удалением.
- Горячая правка QML: `FileView` на файлах виджета, перезагрузка только его
  экземпляров через cache-busting URL; чужие экземпляры не трогаются.

### Тема и материалы

- `ctx.colors` — Material-роли из общего `Theme`: `surface`, `onSurface`,
  `surfaceVariant`, `onSurfaceVariant`, `primary`, `onPrimary`,
  `primaryContainer`, `onPrimaryContainer`, `secondary`, `onSecondary`,
  `tertiary`, `outline`, `error`. В `accent` это палитра shell, в `widget` —
  палитра из `manifest.palette` с подстановкой недостающих ролей.
- `MaterialRegistry`: пользовательские материалы
  `$XDG_CONFIG_HOME/quickshell/widgets/materials` и встроенные
  `<shellDir>/materials`, приоритет у пользовательских.
- Встроенные: `solid`, `transparent`, `gradient`, `grain`, `glass`.
  `glass` и `grain` — шейдеры `.frag` → `.frag.qsb` (`qsb --qt6`),
  сборка: `widgets/tools/build-shaders.sh`.
- Глобальные параметры — материал и режим цвета по умолчанию; задаются в
  «Параметрах виджетов» (ПКМ по рабочему столу) или в `config.json`
  (`defaults.material`, `defaults.colorMode`). Экземпляр может переопределить
  их и вернуться к глобальному значению кнопкой «По умолчанию» в своих
  настройках.
- Ограничение выбора — `materials`/`colorModes` манифеста. Смена материала или
  цвета не перезагружает контент виджета.
- Радиус всех карточек — `0.28·cell`; по умолчанию все встроенные виджеты
  используют один материал (`glass`).

### Раскладка

- `LayoutStore` пишет `$XDG_STATE_HOME/quickshell/widgets/layout.json` через
  `FileView` + `JsonAdapter`: атомарная запись, debounce 500 мс, `schema: 1`.
- Для экрана хранится текущая сигнатура `cols x rows`, `grid`, `widgets`,
  `tray` и карта `signatures`. Возврат к известной сигнатуре восстанавливает
  точную раскладку.
- Новая сигнатура: пропорциональный масштаб, нормализация размеров, поиск
  ближайшего свободного места; не поместившиеся — в `tray`.
- При первом запуске группа встроенных виджетов центрируется.
- Отладочная сетка, drag/resize, undo/redo, «Готово»/«Отмена», Esc.

### Редактор

- Вход — **ПКМ по рабочему столу → «Изменить расположение»** (кнопки «Править»
  больше нет) или IPC `edit toggle`. То же меню: «Добавить виджет…»,
  «Параметры виджетов…», «Готово», «Отмена».
- Редактор — режим основного слоя: `Overlay`, `OnDemand`-фокус, полная маска
  ввода, затемнение. Меню, каталог и настройки — `Item` внутри этого же окна.
- Выделение — **зелёный скруглённый контур по форме карточки**, без квадратной
  рамки и без квадратных ручек. Клик выбирает виджет; тянуть за контур —
  менять размер, за середину — перемещать.
- Drag: призрак-рамка по клеткам, карточка следует за мышью, на отпускании
  плавно встаёт в цель; невалидная позиция возвращается.
- Resize: контур/стороны/углы, только для `scalable`; во время жеста виден
  призрак, после отпускания размер плавно анимируется; `allowed`/диапазон и
  коллизии соблюдаются.
- Undo/redo (снимки раскладки, до 50), Ctrl+Z/Ctrl+Shift+Z, Esc, «Отмена»
  откатывает сессию. Одиночный клик выделения не создаёт шаг undo.
- Лоток «Не помещается»: вернуть в первое свободное место или удалить.

### Каталог и настройки

- «+» открывает `WidgetPicker` справа: поиск, живые превью `ctx.preview`,
  тап-добавление (default → min → «Нет места»), drag-and-drop с призраком,
  «Добавить папку…» (`Config.addExtraPath` пишет `config.json`).
- Пикер при добавлении/переносе уходит вправо и растворяется; при drag —
  полупрозрачный.
- ⚙ открывает `WidgetSettingsPopup`: материал, режим цвета (у обоих есть
  «По умолчанию»), поля `settings`, «Сбросить», «Удалить», «Закрыть».
  После закрытия/удаления попап полностью исчезает, а не оставляет пустое окно.
- «Параметры виджетов…» в ПКМ-меню открывает `WidgetsGlobalPopup`: материал и
  цвет по умолчанию для всех экземпляров, сброс переопределений. Это тот же
  слой, отдельного окна нет.

## Пути

- Конфиг: `$XDG_CONFIG_HOME/quickshell/widgets/config.json`
  (по умолчанию `~/.config/quickshell/widgets/config.json`), образец —
  `widgets/config.example.json`.
- Состояние: `$XDG_STATE_HOME/quickshell/widgets/layout.json`.
- Встроенные виджеты: `quickshell/builtin-widgets/`.
- Материалы: `quickshell/materials/`.
- Документация автора: `widgets/docs/WIDGET_AUTHORING.md`.

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
  "widgets": { "extraPaths": [] },
  "wallpaper": "",
  "defaults": { "material": "glass", "colorMode": "accent" }
}
```

`showGrid` и `wallpaper` перечитываются на лету; палитра — из `Wal`.

## Структура

```
quickshell/
  shell.qml                   основная оболочка + DesktopLayer + WidgetIpc
  singletons/Theme.qml        общая палитра, включая Material-роли виджетов
  widgets/
    core/                     Config, Registry, LayoutStore, Theme-роли, IPC
    desktop/                  DesktopLayer, WidgetHost, GridOverlay
    editor/                   DragController, PickerState, Picker, Settings,
                              DesktopContextMenu, WidgetsGlobalPopup
    tools/build-shaders.sh
    docs/WIDGET_AUTHORING.md
  builtin-widgets/            my.clock, my.note, my.color, my.allowed,
                              my.palette, my.switch
  materials/                  solid/transparent/gradient/grain/glass
```

## Известные ограничения

- Перетаскивание из лотка пока заменено кнопкой «вернуть».
- В обычном режиме слой перехватывает клики по пустому рабочему столу (это
  нужно для ПКМ-меню); окна выше слоя работают как обычно.
- Касания идут через `MouseArea` (эмуляция указателя); multitouch-жестов нет.
- `docs/WIDGET_AUTHORING.md` — руководство для авторов виджетов.
