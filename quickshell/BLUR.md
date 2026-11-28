# Блюр в оболочке: Android 16/17, dual Kawase и backdrop

Пометка для будущих чатов. Всё, что касается размытия, живёт **внутри
Quickshell**. Правила `layerrule` в `~/.config/hypr/hyprland.lua` для этих
панелей не нужны и не должны добавляться: фон панелей запрашивается у
композитора через `ext-background-effect-v1`, а внутренний контент
размывается собственным шейдером.

Версии на момент внедрения: Quickshell 0.3.2, Qt 6.12.1, Hyprland 0.57.2.

## Что сделано

| Место | Что размывается | Чем |
|---|---|---|
| Панель быстрых настроек (`quickshell-quick`) | фон под карточкой | `BackgroundEffect` (композитор) |
| Центр уведомлений | фон под карточкой | `BackgroundEffect` |
| Панель плеера | фон под карточкой; обложка как фон, если играет трек | `BackgroundEffect` / `KawaseBlur` |
| OSD громкости/яркости | фон под карточкой | `BackgroundEffect` |
| Переключатель профилей Hyprland | фон под карточкой | `BackgroundEffect` |
| Alt+Tab (`WindowSwitcher`) | фон под панелью | `BackgroundEffect` |
| Док | фон только в раскрытом виде | `BackgroundEffect` |
| Экран блокировки | обои | `KawaseBlur` |
| Карточки виджетов рабочего стола | обои / соседние виджеты | старый `materials/glass` (9-tap), не трогали |

Сознательно **не** размываются: бар (постоянный элемент), тосты
уведомлений (мелкие, каждая поверхность считалась бы отдельно), окно
настроек, модальные диалоги (scrim уже есть; blur поверх blur — двойная
стоимость), компактный док, карточки виджетов. Для мелкого текста важнее
тонировка, а не блюр.

## Как устроен backdrop панелей

`BackgroundEffect` — attached-свойство Quickshell.Wayland (протокол
`ext-background-effect-v1`). Оно ставится **на окно**, не на дочерний Item:

```qml
PanelWindow {
    id: root
    color: "transparent"

    BackgroundEffect.blurRegion: Region {
        item: card          // регион = карточка, а не всё окно
        radius: Theme.shape.xl
    }
}
```

Hyprland 0.57 умеет `ext-background-effect-v1`; регион приходит как
`wl_region`, поэтому прозрачная часть полноэкранной layer-поверхности не
размывается, а скругление карточки учитывается (Region растеризует радиус
в прямоугольники).

Важно: `PopupWindow` (xdg-popup) в Hyprland этот протокол не применяет —
в `CPopup::shouldBlur()` проверяется только глобальная настройка
`decoration:blur:popups`, а не `m_hasBackgroundEffect`. Поэтому панель
быстрых настроек переведена с `PopupWindow` на отдельный `PanelWindow`
(`quickshell-quick`, Overlay, правый верхний угол). Клик мимо закрывает её
через `HyprlandFocusGrab`; после снятия grab'а на 150 мс игнорируется
`toggle()`, чтобы тот же клик по кнопке статуса не открыл панель снова.

Если композитор не поддерживает `ext-background-effect-v1`, панели
останутся полупрозрачными без блюра. Это осознанный компромисс: оболочка
рассчитана на Hyprland. Проверка — `qs log`: Quickshell предупреждает, что
background effect не поддерживается.

## Dual Kawase: что именно повторяем

Ориентир — AOSP `frameworks/native/libs/renderengine/skia/filters/
KawaseBlurDualFilterV2.cpp` (copyright 2025, флаг `window_blur_kawase2`).
Зеркало для чтения:
<https://raw.githubusercontent.com/Lunaris-AOSP/frameworks_native/16.2/libs/renderengine/skia/filters/KawaseBlurDualFilterV2.cpp>

Ключевые вещи из кода:

- Первый проход — сразу в **1/4** разрешения, 4 сэмпла по диагоналям
  (STEP = ±0.25 в координатах результата).
- Остальные даунсэмплинги — в 2 раза, центр с весом 4 и 4 угла с весом 1,
  сумма делится на 8.
- Апсемплинг — центр + 7 вершин правильного семиугольника, все веса равные
  (`c * 0.125`), плюс crossfade с более тонким уровнем:
  `alpha = min(1, filterDepth - i)`.
- `radius = blurRadius * 0.57735` (компенсация разницы Kawase и гауссова
  блюра, как в Skia).
- `filterDepth = min(kMaxSurfaces - 1, radius * kInputScale / 2.5)`, где
  `kInputScale = 0.25`, `kMaxSurfaces = 4`.
- `filterPasses = min(3, ceil(filterDepth))`.
- Offset апсемплинга считается решением уравнения по сумме квадратов
  радиусов; формула перенесена в `KawaseBlur.qml` (`computeStep()`).

## Наша реализация

Файлы:

- `quickshell/components/effects/KawaseBlur.qml`
- `quickshell/components/effects/kawase-down-quarter.frag` + `.qsb`
- `quickshell/components/effects/kawase-down-half.frag` + `.qsb`
- `quickshell/components/effects/kawase-up.frag` + `.qsb`
- `quickshell/components/effects/kawase-composite.frag` + `.qsb`

Цепочка: `Image/ShaderEffectSource` → L0 (1/4) → L1 (1/8) → L2 (1/16) →
L3 (1/32, только при 4 уровнях) → up3 → up2 → up1 → up0 → финальный
композит в полном разрешении. Финальный проход добавляет тонировку,
сатурацию, яркость и маску скругления. Уровни выбираются автоматически
(`levels: 0`), 2–4; для радиусов ~20–120 px обычно хватает 3–4.

`sourceItem` обязан быть texture provider'ом:

- `Image` (в т.ч. невидимый), `ShaderEffectSource`, или Item с
  `layer.enabled`. Для скрытого изображения проверены оба варианта:
  `layer.enabled: true` и `ShaderEffectSource { hideSource: true }`.
- Голый `Rectangle`/`Item` без layer не подойдёт.

Сборка шейдеров (Qt 6):

```sh
cd quickshell/components/effects
qsb --qt6 -o kawase-down-quarter.frag.qsb kawase-down-quarter.frag
qsb --qt6 -o kawase-down-half.frag.qsb kawase-down-half.frag
qsb --qt6 -o kawase-up.frag.qsb kawase-up.frag
qsb --qt6 -o kawase-composite.frag.qsb kawase-composite.frag
```

`.qsb` лежат в репозитории рядом с `.frag`; после правки GLSL их нужно
пересобрать. Проверка: `qsb -d файл.frag.qsb`.

## Оптимизации и ограничения

- Основная работа идёт на текстурах 1/4–1/32, финальный проход — один
  fullscreen-shader. Для больших радиусов это дешевле `MultiEffect.blur`
  (который на экране блокировки раньше делал blurMax: 64 в полном
  разрешении).
- Минимум уровней под нужный радиус: не ставьте `levels: 4` для 12 px.
- `live: true` обновляет цепочку каждый кадр. Для статичного источника
  можно выставить `live: false` и обновлять вручную; сейчас в плеере
  `live` привязан к видимости панели, на экране блокировки — всегда true,
  потому что экран статичен и цена мала.
- Не размывайте blur: если у карточки есть собственный непрозрачный
  backdrop (обложка плеера), `BackgroundEffect.blurRegion` для неё
  отключается (`artBackdrop.visible ? null : cardBlurRegion`).
- Не анимируйте регион blur каждый кадр: двигайте `item`, а не
  пересоздавайте `Region`.
- `Region.radius` — целое; для карточки берите тот же радиус, что у
  `Rectangle`.
- Тонировка обязательна: `tint` (surface-роль темы) + `tintOpacity` 0.74–
  0.86, иначе мелкий текст теряет контраст. В панелях тонировка — это
  `Theme.panelBlurSurface` / `sheetBlurSurface` (альфа 0.82/0.86).

## Как проверять

```sh
qs ipc -p ~/shell/quickshell call bar main        # быстрые настройки
qs ipc -p ~/shell/quickshell call bar close
qs ipc -p ~/shell/quickshell call notifications toggle
qs ipc -p ~/shell/quickshell call player open
qs ipc -p ~/shell/quickshell call player close
qs ipc -p ~/shell/quickshell call dock expand
qs ipc -p ~/shell/quickshell call dock collapse
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40       # OSD
qs log -p ~/shell/quickshell -t 100              # ошибки QML/шейдеров
hyprctl layers                                    # namespace'ы поверхностей
```

Для скриншота: `grim -g "x,y w h"` (координаты логические; на HiDPI grim
отдаёт физические пиксели). На экране блокировки проверять только
блокировкой либо отдельным окном с `LockSurface`: это security-критичный
код, не подменяйте путь снятия блокировки.

## Чего не делать

- Не добавлять `layerrule = blur` для `quickshell-*` в hyprland.lua: это
  дублирует `BackgroundEffect` и смешивает две модели владения blur.
- Не пытаться размыть чужие окна собственным шейдером: layer-поверхность
  не читает пиксели других окон. Для этого только композитор
  (`BackgroundEffect` / его blur).
- Не ставить блюр на каждую иконку/пилюлю/чип: цепочка проходов на
  мелких элементах — это расход батареи без визуальной пользы.
- Не использовать `MultiEffect.blur` для больших радиусов.
- Не оставлять полноэкранные пробы на живом экране: surface без маски
  перехватывает ввод. Для проб задавайте `mask: Region {}` (пустой) и
  `WlrLayershell.focusable: false`.
