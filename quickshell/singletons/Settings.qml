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
        const state = Quickshell.env("XDG_STATE_HOME");
        const base = state !== "" ? state : Quickshell.env("HOME") + "/.local/state";
        return base + "/quickshell";
    }
    readonly property string path: root.dir + "/settings.json"

    // Плоская карта ключ → значение; пересобирается целиком, потому что QML
    // не замечает изменения полей объекта.
    property var values: ({})
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

    function flush() {
        if (!root.loaded || !root.dirReady)
            return;
        file.setText(JSON.stringify(root.values, null, 2) + "\n");
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
