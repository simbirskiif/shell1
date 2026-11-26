# Локализация оболочки

Строки интерфейса живут в `i18n/<код>.json` — плоских словарях «ключ → строка».
Английский и русский лежат рядом: `en.json` и `ru.json`. Ключи с точками
группируют строки по поверхностям (`settings.*`, `quick.*`, `lock.*`), поэтому
в коде сразу видно, откуда фраза.

```json
{
  "settings.language.title": "Язык",
  "caffeine.duration.hours": {
    "one": "{n} час",
    "few": "{n} часа",
    "many": "{n} часов"
  }
}
```

## Использование

```qml
import "../../singletons"

Text { text: I18n.tr("settings.language.title") }

// Подстановка: {0}, {1}… или именованные {name}, {count}.
Text { text: I18n.tr("network.error.forget", { name: ssid }) }

// Число с правильной формой (ru: one/few/many, en: one/other).
Text { text: I18n.trn("quick.privacy.duration.minutes", minutes) }

// Перевод с исходной строкой, если ключа нет (сторонние виджеты).
text: I18n.trOr("widget.my.clock.name", "Часы")
```

`I18n.tr()` читает свойства singleton-а, поэтому обычная привязка
`text: I18n.tr(...)` сама пересчитывается при смене языка и загрузке словаря.
Перезапуск оболочки не нужен. Правка JSON подхватывается на лету
(`FileView.watchChanges`).

Если ключа нет в выбранном языке, берётся английская строка, а если нет и
там — сам ключ. Так недоперевод не ломает интерфейс.

## Выбор языка

Настройки хранятся в общем `settings.json` (см. `singletons/Settings.qml`):

- `language.mode` — `"system"` (по умолчанию) или код языка (`"en"`, `"ru"`);
- `language.fallback` — запасной язык приложения (`"en"` по умолчанию).

Порядок выбора в `singletons/I18n.qml`:

1. явный `language.mode`, если это поддерживаемый язык;
2. язык системы из `LC_ALL` → `LC_MESSAGES` → `LANG` (для `C`/`POSIX`
   дополнительно спрашивается `Qt.locale()`);
3. `language.fallback`, если системный язык не поддерживается.

Раздел «Язык» в окне настроек (`components/settings/SettingsLanguagePage.qml`)
показывает определённый системный язык и действующий язык, позволяет выбрать
режим «Как в системе», конкретный язык и запасной язык. Изменения применяются
сразу.

## Как добавить язык

1. Добавить код и самоназвание в `I18n.supported`.
2. Положить `i18n/<код>.json` (можно начать с копии `en.json`).
3. Добавить пункты в `supportedCodes` — списки опций в настройках строятся из
   `I18n.supported`.

Язык экрана блокировки влияет и на формат даты: `Qt.locale(I18n.locale)`.

## Виджеты и материалы

Названия встроенных виджетов и подписи их настроек переводятся через
необязательный блок `i18n` в `manifest.json`:

```json
{
  "name": "Часы",
  "i18n": {
    "en": {
      "name": "Clock",
      "description": "Digital clock with date",
      "settings": {
        "format24": { "label": "24-hour format" },
        "align": { "label": "Alignment", "options": { "left": "Left", "center": "Center" } }
      }
    }
  }
}
```

Исходные `name`/`description`/`label` остаются языком-основой (сейчас русским);
при отсутствии блока виджет показывается как есть. Читает переводы
`WidgetRegistry.displayName()/displaySettingLabel()/displaySettingOption()`.

Названия материалов ищутся по ключам `material.<id>.name` (запасной вариант —
`name` из `meta.json`).
