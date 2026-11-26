pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Локализация оболочки: словари в i18n/<код>.json и выбор языка.
//
// Формат — плоский JSON «ключ → строка». Ключи с точками группируют строки
// по поверхностям (settings.*, quick.*, lock.*), поэтому в коде видно, откуда
// строка, а не просто tr("...").
//
// Язык выбирается по трём правилам, в порядке приоритета:
//   1. language.mode — явный язык ("en"/"ru"); "system" означает «как в системе»;
//   2. язык системы из LC_ALL/LC_MESSAGES/LANG (или Qt.locale());
//   3. language.fallback — запасной язык приложения, если системный не
//      поддерживается (по умолчанию английский).
//
// tr() читает свойства singleton-а, поэтому обычная привязка
// `text: I18n.tr("key")` сама пересчитывается при смене языка и загрузке
// словаря — перезапускать оболочку не нужно.
Singleton {
    id: root

    // Поддерживаемые языки в порядке показа. name — самоназвание языка,
    // его не переводят.
    readonly property var supported: [
        { code: "en", name: "English" },
        { code: "ru", name: "Русский" }
    ]
    readonly property var supportedCodes: ["en", "ru"]

    // Словари. Загружаются оба сразу, чтобы переключение языка было
    // мгновенным и не мигало пустыми строками.
    property var english: ({})
    property var russian: ({})
    property bool englishLoaded: false
    property bool russianLoaded: false

    // «system» или код языка.
    readonly property string mode: {
        const stored = String(Settings.value("language.mode", "system"));
        return root.isSupported(stored) ? stored : "system";
    }
    // Запасной язык приложения. Неизвестное или неподдерживаемое значение
    // заменяем английским, чтобы язык никогда не оставался пустым.
    readonly property string fallback: {
        const stored = root.normalize(Settings.value("language.fallback", "en"));
        return root.isSupported(stored) ? stored : "en";
    }

    // Сырое значение локали из окружения: "ru_RU.UTF-8", "en_US", "C".
    readonly property string systemLocale: {
        let value = Quickshell.env("LC_ALL");
        if (value === null || value === undefined || value === "")
            value = Quickshell.env("LC_MESSAGES");
        if (value === null || value === undefined || value === "")
            value = Quickshell.env("LANG");
        const text = String(value === null || value === undefined ? "" : value);
        if (text !== "" && text !== "C" && text !== "POSIX")
            return text;
        // Окружение молчит (частый случай при запуске из systemd) — берём
        // локаль, которую видит сам Qt.
        const languages = Qt.locale().uiLanguages;
        if (languages !== undefined && languages !== null && languages.length > 0)
            return String(languages[0]);
        return String(Qt.locale().name || text);
    }
    // Базовый код языка системы ("ru") или "" для неподдерживаемого.
    readonly property string systemLanguage: {
        const code = root.normalize(root.systemLocale);
        return root.isSupported(code) ? code : "";
    }

    // Действующий язык: явный выбор → системный → запасной.
    readonly property string locale: {
        if (root.mode !== "system")
            return root.mode;
        if (root.systemLanguage !== "")
            return root.systemLanguage;
        return root.fallback;
    }
    readonly property string languageName: root.nameFor(root.locale)
    // Системный язык выбран, но не поддерживается — работает запасной.
    readonly property bool usingFallback: root.mode === "system" && root.systemLanguage === ""

    readonly property var strings: root.locale === "ru" ? root.russian : root.english
    // Английский — база: если в русском словаре ключа ещё нет, показываем
    // английскую строку, а не сырой ключ.
    readonly property var baseStrings: root.english

    readonly property bool loaded: root.englishLoaded && root.russianLoaded
    // Каталог словарей. Quickshell.shellDir — путь к каталогу конфигурации;
    // FileView читает обычный путь, а не URL, поэтому собираем строку.
    readonly property string directory: {
        const base = String(Quickshell.shellDir || "");
        return base.endsWith("/") ? base + "i18n/" : base + "/i18n/";
    }

    function isSupported(code) {
        const value = String(code === undefined || code === null ? "" : code);
        return root.supportedCodes.indexOf(value) >= 0;
    }

    // "ru_RU.UTF-8" / "ru-RU" → "ru"; всё непонятное → "".
    function normalize(value) {
        let text = String(value === undefined || value === null ? "" : value).trim();
        if (text === "")
            return "";
        const dot = text.indexOf(".");
        if (dot >= 0)
            text = text.substring(0, dot);
        const at = text.indexOf("@");
        if (at >= 0)
            text = text.substring(0, at);
        text = text.replace(/-/g, "_");
        const underscore = text.indexOf("_");
        if (underscore >= 0)
            text = text.substring(0, underscore);
        return text.toLowerCase();
    }

    function nameFor(code) {
        for (let i = 0; i < root.supported.length; ++i) {
            if (root.supported[i].code === code)
                return root.supported[i].name;
        }
        return String(code);
    }

    // Явный язык интерфейса. Некорректный код трактуется как «системный».
    function setMode(code) {
        const value = String(code === undefined || code === null ? "" : code);
        Settings.setValue("language.mode", root.isSupported(value) ? value : "system");
    }

    // Запасной язык приложения.
    function setFallback(code) {
        const value = root.normalize(code);
        Settings.setValue("language.fallback", root.isSupported(value) ? value : "en");
    }

    // Есть ли ключ в словаре. Нужен для подписей из внешних манифестов:
    // там строки не наши, и при отсутствии перевода показываем оригинал.
    function has(key) {
        const name = String(key);
        const dict = root.strings || ({});
        if (Object.prototype.hasOwnProperty.call(dict, name))
            return true;
        const base = root.baseStrings || ({});
        return Object.prototype.hasOwnProperty.call(base, name);
    }

    // Перевод с запасным оригиналом: trOr("widget.my.clock.name", "Часы").
    function trOr(key, fallback, params) {
        if (!root.has(key))
            return root.format(fallback, params);
        return root.tr(key, params);
    }

    // Строка по ключу. params — массив ({0}, {1}) или объект ({n}, {name}).
    // Если значение в словаре — объект с формами числа, выбирается форма по
    // params.n (см. trn()).
    function tr(key, params) {
        let value = root.raw(key);
        if (value !== null && typeof value === "object") {
            const number = root.paramNumber(params);
            value = root.pluralForm(value, number);
        }
        return root.format(value, params);
    }

    // Строка с числом: trn("notifications.count", 3) → "3 уведомления".
    function trn(key, n, params) {
        let value = root.raw(key);
        if (value !== null && typeof value === "object")
            value = root.pluralForm(value, n);
        const merged = {};
        if (params !== undefined && params !== null && typeof params === "object") {
            for (const name in params)
                merged[name] = params[name];
        }
        merged.n = n;
        return root.format(value, merged);
    }

    function raw(key) {
        const name = String(key);
        const dict = root.strings || ({});
        if (Object.prototype.hasOwnProperty.call(dict, name))
            return dict[name];
        const base = root.baseStrings || ({});
        if (Object.prototype.hasOwnProperty.call(base, name))
            return base[name];
        return name;
    }

    function paramNumber(params) {
        if (params === undefined || params === null)
            return 0;
        if (typeof params === "number")
            return params;
        if (typeof params === "object" && params.n !== undefined)
            return Number(params.n) || 0;
        return 0;
    }

    function pluralForm(forms, number) {
        const n = Math.abs(Number(number) || 0);
        const integer = Math.floor(n) === n;
        if (root.locale === "ru" && integer) {
            const mod10 = n % 10;
            const mod100 = n % 100;
            if (mod10 === 1 && mod100 !== 11)
                return forms.one !== undefined ? forms.one : forms.other;
            if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
                return forms.few !== undefined ? forms.few : forms.other;
            return forms.many !== undefined ? forms.many
                                            : (forms.other !== undefined ? forms.other : forms.one);
        }
        return n === 1 ? (forms.one !== undefined ? forms.one : forms.other)
                       : (forms.other !== undefined ? forms.other : forms.one);
    }

    function format(text, params) {
        let value = String(text === undefined || text === null ? "" : text);
        if (params === undefined || params === null)
            return value;
        if (Array.isArray(params)) {
            for (let i = 0; i < params.length; ++i)
                value = value.split("{" + i + "}").join(String(params[i]));
            return value;
        }
        if (typeof params === "object") {
            for (const name in params)
                value = value.split("{" + name + "}").join(String(params[name]));
        }
        return value;
    }

    function parse(text, code) {
        if (!text || String(text).trim() === "")
            return ({});
        try {
            const parsed = JSON.parse(text);
            if (parsed !== null && typeof parsed === "object" && !Array.isArray(parsed))
                return parsed;
            console.warn("I18n: словарь " + code + " должен быть объектом");
        } catch (error) {
            console.warn("I18n: не удалось разобрать словарь " + code + ": " + error);
        }
        return ({});
    }

    FileView {
        id: englishFile

        path: root.directory + "en.json"
        watchChanges: true
        preload: true
        // Словарь небольшой: читаем его синхронно при создании singleton-а,
        // чтобы первый кадр не успел показать сырые ключи.
        blockLoading: true
        printErrors: true
        onLoaded: {
            root.english = root.parse(englishFile.text(), "en");
            root.englishLoaded = true;
        }
        onLoadFailed: {
            root.englishLoaded = true;
            console.warn("I18n: не удалось загрузить", englishFile.path);
        }
        onFileChanged: reload()
    }

    FileView {
        id: russianFile

        path: root.directory + "ru.json"
        watchChanges: true
        preload: true
        blockLoading: true
        printErrors: true
        onLoaded: {
            root.russian = root.parse(russianFile.text(), "ru");
            root.russianLoaded = true;
        }
        onLoadFailed: {
            root.russianLoaded = true;
            console.warn("I18n: не удалось загрузить", russianFile.path);
        }
        onFileChanged: reload()
    }
}
