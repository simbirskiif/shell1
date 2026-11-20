pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Настройки оболочки одним JSON-файлом: переживают и перезапуск, и правку
// конфига (Quickshell перезагружает оболочку на каждое сохранение файла, так
// что хранить настройки в памяти бессмысленно).
//
// Место — XDG_STATE_HOME (по умолчанию ~/.local/state/quickshell): это
// состояние оболочки, а не то, что пользователь правит руками, поэтому в
// каталог конфига и в репозиторий файл не пишем.
//
// Чтение — на старте, запись откладывается: перестановка плиток и ползунок
// чувствительности не должны писать на диск на каждое движение.
Singleton {
    id: root

    readonly property string dir: {
        // Quickshell.env() для незаданной переменной возвращает null, а не
        // пустую строку: без этой проверки путь превратился бы в "null/...".
        const state = Quickshell.env("XDG_STATE_HOME");
        const home = Quickshell.env("HOME") || "";
        const base = (state === "" || state === null || state === undefined)
            ? home + "/.local/state" : state;
        return base + "/quickshell";
    }
    readonly property string path: root.dir + "/settings.json"

    // Плоская карта ключ → значение; пересобирается целиком, потому что QML
    // не замечает изменения полей объекта.
    property var values: ({})
    // Ключи, изменённые ЭТИМ экземпляром с прошлой записи. На диск пишем их
    // поверх актуального файла, а не всю карту: оболочка может работать не в
    // одном экземпляре (например, старый процесс после перезапуска), и запись
    // целой карты затирала бы чужие только что сохранённые настройки.
    property var dirty: ({})
    property var pendingWrite: ({})
    property bool writing: false
    // Пока файл не прочитан (или не выяснено, что его нет), значения из
    // настроек не применяются и не сохраняются: иначе дефолты затрёт файл.
    property bool loaded: false
    property bool dirReady: false

    function value(key, fallback) {
        const stored = root.values[key];
        return stored === undefined ? fallback : stored;
    }

    function setValue(key, value) {
        if (root.values[key] === value)
            return;
        root.values = root.withValue(root.values, key, value);
        root.dirty = root.withValue(root.dirty, key, value);
        save.restart();
    }

    function withValue(map, key, value) {
        const next = {};
        for (const existing in map)
            next[existing] = map[existing];
        next[key] = value;
        return next;
    }

    function apply(text) {
        // Сначала значения, потом loaded: потребители слушают именно loaded
        // и в этот момент уже должны видеть прочитанное.
        if (text) {
            let parsed = null;
            try {
                parsed = JSON.parse(text);
            } catch (error) {
                console.warn("Settings: не удалось разобрать", root.path, error);
            }
            if (parsed !== null && typeof parsed === "object" && !Array.isArray(parsed))
                root.values = parsed;
        }
        root.loaded = true;
    }

    // Перечитать актуальный файл и наложить на него наши изменённые ключи.
    // Чтение асинхронное (FileView), запись — после того как файл прочитан:
    // иначе гонка с другим экземпляром снова затирала бы его настройки.
    function flush() {
        if (!root.loaded || !root.dirReady)
            return;
        if (Object.keys(root.dirty).length === 0)
            return;
        // Предыдущая запись ещё читает файл: её finishWrite() увидит новые
        // грязные ключи и запланирует ещё одно сохранение.
        if (root.writing)
            return;
        root.writing = true;
        root.pendingWrite = root.dirty;
        root.dirty = ({});
        disk.reload();
        writeWatchdog.restart();
    }

    function finishWrite() {
        let merged = {};
        const text = disk.text();
        if (text) {
            try {
                const parsed = JSON.parse(text);
                if (parsed !== null && typeof parsed === "object" && !Array.isArray(parsed))
                    merged = parsed;
            } catch (error) {
                console.warn("Settings: не удалось разобрать", root.path, error);
            }
        }
        for (const key in root.pendingWrite)
            merged[key] = root.pendingWrite[key];
        root.pendingWrite = ({});
        root.values = merged;
        root.writing = false;
        writeWatchdog.stop();
        file.setText(JSON.stringify(merged, null, 2) + "\n");
        if (Object.keys(root.dirty).length > 0)
            save.restart();
    }

    FileView {
        id: file
        path: root.path
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoadedChanged: if (loaded) root.apply(text())
        // Файла ещё нет — это нормальный первый запуск, а не ошибка.
        onLoadFailed: root.loaded = true
        onSaved: root.loaded = true
        onSaveFailed: error => console.warn("Settings: не удалось сохранить настройки:", error)
    }

    // Читатель актуального файла для слияния перед записью. Отдельный от
    // FileView записи: тот держит собственный буфер и не перечитывает файл
    // перед каждым сохранением.
    FileView {
        id: disk

        path: root.path
        watchChanges: false
        printErrors: false

        onLoaded: {
            if (root.writing)
                root.finishWrite();
        }

        onLoadFailed: {
            // Файла нет (или он не читается): пишем только наши ключи.
            if (root.writing)
                root.finishWrite();
        }
    }

    // Страховка: если FileView почему-то не пришлёт onLoaded (например,
    // файл исчез между чтениями), запись всё равно завершится.
    Timer {
        id: writeWatchdog

        interval: 1500
        repeat: false
        onTriggered: {
            if (root.writing) {
                console.warn("Settings: чтение перед записью не завершилось, пишем как есть");
                root.finishWrite();
            }
        }
    }

    // Каталог состояния может не существовать: без него FileView не запишет.
    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.dir]
        running: true
        onExited: (code, status) => {
            root.dirReady = code === 0;
            if (!root.dirReady)
                console.warn("Settings: не удалось создать каталог", root.dir);
            else
                root.flush();
        }
    }

    Timer {
        id: save
        interval: 400
        onTriggered: root.flush()
    }
}
