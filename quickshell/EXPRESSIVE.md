# Material 3 Expressive в оболочке

Это не «аккуратный M3». Expressive — живой, смелый, слегка непредсказуемый:
формы морфятся, движение на пружинах, цвета контрастные, типографика
крупная и с характером. Если элемент выглядит ровным и нейтральным —
он сделан неправильно.

## Готовые примитивы

Все лежат в `components/expressive/` (из `components/quick` — `import "../expressive"`,
из `components/` — `import "expressive"`).

### Движение — только пружины

| Компонент | Где применять |
|-----------|---------------|
| `SpringSpatial` | позиция, размер, радиус, поворот, масштаб: с перелётом |
| `SpringSpatialFast` | нажатия, hover, мелкие сдвиги: быстрее, перелёт меньше |
| `SpringEffects` | прозрачность: без перелёта |

```qml
Behavior on width { SpringSpatial {} }
x: expanded ? 120 : 20
```

`MotionNumber` теперь тоже `SpringAnimation` (старые `duration`/`curve`
принимаются, но игнорируются). Новый код пишите сразу на `SpringSpatial` /
`SpringEffects`. `NumberAnimation`/`ColorAnimation` с bezier-кривыми и
длительностями для движения не использовать. Для цвета допустим короткий
`ColorAnimation { duration: 140 }` (у цвета нет пружины в Qt), но всё, что
движется/меняет размер/форму — только пружина.

### Формы

`MorphShape` — контур, который морфится между пресетами:
`circle`, `squircle`, `pill`, `cookie` (волнистый круг), `sunny` (лучики),
`clover` (четырёхлистник), `burst` (острые лучи), `blob` (неровное пятно).

```qml
MorphShape {
    anchors.fill: parent
    shape: active ? "cookie" : "squircle"   // смена = морфинг на пружине
    color: Theme.primaryContainer
    borderWidth: active ? 0 : 1
    borderColor: Theme.outlineVariant
    modulation: 0.5   // для широких плиток: спокойнее амплитуда
}
```

Правила:
- состояние читается формой: активный toggle — cookie/clover/sunny, неактивный — squircle/circle;
- рядом должны соседствовать контрастные формы (круг, пилюля, выступ), но не хаос:
  фон больших плиток — `modulation` 0.4–0.6, иконки-орбы — 1.0;
- при нажатии форма меняется (например, burst → squircle) и элемент сжимается.

### Кнопки и группы

- `ExpressiveFab { icon; tone: "primary"|"tertiary"|"secondary"; shape: "cookie"; hoverShape: "squircle"; size: 56; onClicked }`
  — главные действия (настройки, раскрытие дока, подтверждение).
- `SegmentedButtonGroup { tabs: [{key,title}]; current; onSelected(key) }` —
  склеенные кнопки: активный сегмент шире, при нажатии соседи поджимаются.

### Готовые компоненты

- `ToggleSwitch` (quick) — Expressive-переключатель: ручка морфит circle ↔
  squircle, тянется при нажатии. API прежний (`checked`, `toggled()`).
- `PanelSlider` (quick) — волнистая дорожка + толстая ручка; `value`, `moved(real)`,
  `accent` (primary/tertiary).
- `LoadingIndicator` (quick) — морфящаяся клякса вместо дуги.

## Цвет

Не только primary и surface. В одной панели должны быть 2–3 акцента:

- `Theme.primaryContainer` — главный акцент;
- `Theme.tertiaryContainer` — второй, неожиданный (у оранжевых обоев он оливковый);
- `Theme.secondaryContainer` — третий, спокойный;
- `Theme.surfaceContainerHigh` — фон неактивного.

Пары: `onPrimaryContainer` на `primaryContainer`, `onTertiaryContainer` на
`tertiaryContainer`, `onSecondaryContainer` на `secondaryContainer`.
Группировка — формой и цветом, а не тонкими разделителями. Разделитель
`outlineVariant` — только если без него совсем не читается, и не в каждом списке.

## Типографика

Roboto Flex (variable). Используйте `Theme.typeEmphasized*` для часов,
заголовков, активных пунктов, крупных чисел — они жирнее и уже. Обычные
`Theme.type*` — для тела. Контраст размеров резкий: заголовок 24–26,
подпись 11–12, тело 14–16.

## Размеры

Touch-цели 48+, крупные иконки 20–24, воздуха больше вокруг акцентов.
Асимметрия разрешена: соседние элементы могут быть разного размера и формы.

## Проверка

```bash
cd /home/adm_a/shell/quickshell
/usr/lib/qt6/bin/qmllint <файлы>          # ошибок быть не должно
qs -p /home/adm_a/shell/quickshell log -t 60 | grep -E "ERROR|Loaded"
```

Скриншоты: `grim -g "1400,20 540x840" ...`, IPC — `qs -p ... ipc call bar main`.
Не запускать второй `qs`, не блокировать экран.
