
коммить каждое значимоемое изменение, но не пуш в репозиторий
## Контекст

- Проект: оболочка на Quickshell (QML, Wayland, Qt 6). Версия Quickshell: `Quickshell 0.3.2 (revision , distributed by Arch Linux)`. Композитор: `Hyprland`.
- Источник истины: https://quickshell.org/docs и исходники модулей. Если не уверен, что тип, свойство или сигнал существует, сказать об этом прямо, а не выдумывать. Не изобретать модули и свойства.

## Чего не делать

1. Не использовать Qt Widgets, `QtQuick.Window` с `Window {}` вместо `PanelWindow`/`FloatingWindow`, `Qt.labs.platform`, `Qt5Compat`, если это не оправдано.
2. Не писать на JS то, что уже есть в сервисах Quickshell. Сначала проверить модули:
   - `Quickshell.Services.Pipewire` (звук)
   - `Quickshell.Services.Mpris` (плееры)
   - `Quickshell.Services.UPower` (батарея)
   - `Quickshell.Services.Notifications` (сервер уведомлений)
   - `Quickshell.Services.SystemTray`
   - `Quickshell.Bluetooth`
   - `Quickshell.Hyprland` / `Quickshell.I3` (воркспейсы, активное окно)
   - `Quickshell.Wayland` (layer-shell, foreign toplevels, session lock)
3. Не дёргать внешние утилиты (`pactl`, `nmcli`, `playerctl`) через `Process`, если есть нативный сервис. Если всё же нужно, то `command: ["prog", "arg"]` массивом, без `sh -c` со строковой подстановкой пользовательских данных.
4. Не опрашивать `Timer`-ом то, что умеет присылать события.
5. Не использовать `Qt.createQmlObject` и `eval`.
6. Не ломать биндинги присваиванием (`width = 10` вместо `width: 10` внутри обработчика). Для императивных случаев использовать `Qt.binding()`.
7. Не городить один гигантский `shell.qml`. Разбивать на компоненты и singleton-ы.

## Окна и мониторы

- Бар/панель: `PanelWindow` с `anchors { top: true; left: true; right: true }`, `implicitHeight`, `exclusiveZone` (или `exclusionMode`).
- Многомониторность: `Variants { model: Quickshell.screens; delegate: PanelWindow { required property var modelData; screen: modelData } }`. Не хардкодить монитор.
- Попапы и меню: `PopupWindow` с `anchor.window`/`anchor.item`/`anchor.rect`, а не абсолютными координатами.
- Слои, фокус клавиатуры, namespace: через `WlrLayershell` (`layer`, `keyboardFocus`, `namespace`). Для оверлеев и лаунчеров осознанно выбирать `keyboardFocus`.
- Закрытие по клику вне окна: `HyprlandFocusGrab` (если Hyprland) или аналог, а не самодельные костыли с mouse area на весь экран.
- Тяжёлые и редко показываемые окна: `LazyLoader`.
- Экран блокировки: `WlSessionLock`. Относиться к нему как к security-критичному коду: никаких fallback-ов, которые пропускают без пароля.

## Архитектура

- Состояние и логика в `pragma Singleton` (`Singleton { }`), UI в отдельных компонентах. Компоненты принимают данные через `required property`.
- Тема (цвета, шрифты, отступы, радиусы) в одном singleton, без магических чисел и хекс-цветов в разметке.
- Файлы читать через `FileView`, процессы через `Process` + `SplitParser`/`StdioCollector`. Не блокировать UI-поток.
- Внешнее управление (бинды, скрипты): `IpcHandler` и `qs ipc call`, а не файлы-флаги и сигналы.
- Пути: `Quickshell.shellPath()`, `Qt.resolvedUrl()`, `Quickshell.iconPath()`. Не хардкодить `/home/user/...`.
- Конфиг пользователя отделять от кода (JSON через `FileView` + `JsonAdapter`).

## Блюр и фон

- Dual Kawase из AOSP RenderEngine живёт в `quickshell/components/effects/KawaseBlur.qml` (+ `.frag.qsb`). Полные формулы, схема цепочки и ограничения — `quickshell/BLUR.md`; перед правками блюра читать его.
- Backdrop панелей — только `BackgroundEffect.blurRegion` (ext-background-effect-v1) на самом `PanelWindow`. **Никаких `layerrule` в `~/.config/hypr` для `quickshell-*`** — это было явное требование; не добавлять их «для надёжности».
- Регион blur у анимированных карточек — `components/effects/AnimatedBlurRegion.qml`, а не `Region { item }`: обычный `Region` не замечает `scale`/`transform`, и пятно отстаёт. OSD двигать через `anchors.bottomMargin`, а на закрытии снимать регион (`... ? region : null`) — у протокола нет альфы региона.
- Настройки блюра: `blur.strength` и `blur.cardContrast` в `Settings`, UI — «Оформление» → «Блюр и карточки», IPC — `appearance blur <s> <c>`. `blur.strength` меняет только радиус Kawase (обои блокировки/обложка): у панельного blur композитора нет параметра силы. `blur.cardContrast` задаёт альфу карточек (`Theme.panelAlpha` / `sheetAlpha` / `artTintOpacity`).
- `PopupWindow` (xdg-popup) не получает background effect в Hyprland. Поэтому панель быстрых настроек — отдельный `PanelWindow` с namespace `quickshell-quick`, а клик мимо закрывает её через `HyprlandFocusGrab`.
- Своим шейдером размывается только внутренний контент: обои на экране блокировки и обложка в панели плеера. Чужие окна шейдер не видит — только композитор.
- Не блюрить: бар, тосты, настройки, модалки, компактный док, отдельные иконки/чипы; не делать blur поверх blur. Тонировка (`Theme.panelBlurSurface` / `sheetBlurSurface`) обязательна для контраста текста.
- После правки GLSL пересобрать `.qsb` через `qsb --qt6 -o ...`; `.qsb` коммитятся вместе с `.frag`.

## Качество кода QML

- Порядок в объекте: `id`, свойства, сигналы, функции, дочерние объекты.
- Типизировать свойства (`property int`, `property string`), не использовать `var` без нужды.
- Использовать `required property`, `readonly property`; `Behavior`/`Animation` умеренно, не анимировать всё подряд, это нагружает CPU/GPU.
- Для списков с большим числом элементов: `ListView`/`Repeater` с моделью, а не ручное создание объектов.
- Следить за утечками: `Connections` с `enabled`, закрывать `Process`, не создавать объекты в циклах без удаления.

## Процесс работы

1. Перед правками прочитать существующий код и стиль проекта. Не переписывать то, что не просили.
2. Менять минимально и точечно. Показывать diff, а не весь файл заново.
3. Если задача неоднозначна, задать один уточняющий вопрос, не додумывать.
4. После правок написать, что проверить: `quickshell -vv` (логи), `qs log`, hot reload. Не утверждать, что «работает», если не запускалось.
5. Ошибки QML (`ReferenceError`, `TypeError`, `Binding loop`, `Cannot assign to non-existent property`) разбирать по тексту лога, а не гадать.
6. Если API неизвестен, предложить посмотреть в доке или в `qmllint`/`qmlls`, а не писать «на глаз».

## Примечание

Список написан по памяти, а API Quickshell активно развивается, поэтому часть имён (особенно в `Services.*` и `Bluetooth`) стоит сверить с докой своей версии.
