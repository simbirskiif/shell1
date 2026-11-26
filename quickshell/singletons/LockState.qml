pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Состояние экрана блокировки.
//
// Здесь только состояние и команды: владение процессами (PAM и fprintd)
// живёт в components/lock/LockAuth.qml, потому что Process/PamContext
// не запускаются из `pragma Singleton` (см. BluetoothHelperHost.qml).
//
// Безопасность: `locked` снимает только finishUnlock(), а unlockSucceeded()
// вызывает исключительно LockAuth после успешного PAM или отпечатка.
// Ни IPC, ни таймеры, ни ошибки PAM не могут снять блокировку сами по себе.
Singleton {
    id: root

    // ── сессия ──────────────────────────────────────────────────────────
    property bool locked: false
    // Композитор подтвердил, что все экраны закрыты lock-поверхностями.
    property bool secure: false
    // Аутентификация прошла: идёт анимация, снимать блокировку пока рано.
    property bool unlocking: false

    // ── аутентификация ─────────────────────────────────────────────────
    property bool authenticating: false
    property int failedAttempts: 0
    // "idle" | "hint" | "error" | "success"
    property string statusKind: "idle"
    property string statusText: ""

    // ── отпечаток ──────────────────────────────────────────────────────
    // "checking" | "ready" | "scanning" | "retry" | "matched" |
    // "unavailable" | "busy" | "error"
    property string fingerprintState: "checking"
    property string fingerprintHint: ""
    property string fingerprintDevice: ""

    // ── клавиатура ─────────────────────────────────────────────────────
    property bool capsLock: false

    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string avatarLetter: root.userName.length > 0
        ? root.userName.charAt(0).toUpperCase() : "?"

    // Флаг блокировки переживает hot reload конфига: без него правка QML
    // пересоздавала бы синглтон с locked = false и молча открывала сессию.
    // Файл пустой — сессия не заблокирована, любое содержимое — заблокирована
    // (fail-closed: недописанный файл оставляет экран блокировки).
    readonly property string runtimeDir: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR");
        if (runtime !== null && runtime !== undefined && runtime !== "")
            return runtime;
        return (Quickshell.env("HOME") || "/tmp") + "/.cache";
    }
    readonly property string statePath: root.runtimeDir + "/quickshell-lock"

    // LockAuth слушает эти сигналы и выполняет I/O.
    signal passwordRequested(string password)
    signal fingerprintRequested()
    signal capsRefreshRequested()

    FileView {
        id: stateFile

        path: root.statePath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        // На старте единственный источник правды — флаг на диске.
        let contents = "";
        try {
            stateFile.waitForJob();
            contents = stateFile.text();
        } catch (error) {
            console.warn("[lock] не прочитал " + root.statePath + ": " + error);
        }
        if (contents.trim().length > 0) {
            root.locked = true;
            console.info("[lock] сессия была заблокирована, сохраняю блокировку");
        }
    }

    // ── команды ────────────────────────────────────────────────────────

    function lock() {
        if (root.locked)
            return;
        root.resetAuth();
        root.locked = true;
        root.writeFlag(true);
        console.info("[lock] сессия заблокирована");
    }

    function submitPassword(value) {
        if (!root.locked || root.unlocking || root.authenticating)
            return false;
        if (value.length === 0)
            return false;
        root.authenticating = true;
        root.setStatus("hint", I18n.tr("lock.checking"));
        root.passwordRequested(value);
        return true;
    }

    function requestFingerprint() {
        if (!root.locked || root.unlocking)
            return;
        if (root.fingerprintState === "checking"
                || root.fingerprintState === "unavailable")
            return;
        root.fingerprintRequested();
    }

    // LockAuth вызывает это ТОЛЬКО при успешной аутентификации.
    function unlockSucceeded() {
        if (!root.locked || root.unlocking)
            return;
        root.unlocking = true;
        root.authenticating = false;
        root.statusKind = "success";
        root.statusText = I18n.tr("lock.unlocked");
        root.fingerprintState = "matched";
        root.fingerprintHint = "";
        console.info("[lock] аутентификация успешна");
    }

    // Снимает блокировку после анимации; вызывает LockSession.
    // Требует unlocking: снять блокировку в обход успешной аутентификации
    // нельзя даже случайным вызовом из другого компонента.
    function finishUnlock() {
        if (!root.locked || !root.unlocking)
            return;
        root.locked = false;
        root.unlocking = false;
        root.setStatus("idle", "");
        root.authenticating = false;
        root.failedAttempts = 0;
        root.fingerprintState = "checking";
        root.fingerprintHint = "";
        root.fingerprintDevice = "";
        root.writeFlag(false);
        console.info("[lock] сессия разблокирована");
    }

    function passwordFailed(text) {
        root.authenticating = false;
        root.failedAttempts += 1;
        root.setStatus("error", text);
        // Caps Lock чаще всего и есть причина «неверного» пароля.
        root.capsRefreshRequested();
    }

    function setStatus(kind, text) {
        root.statusKind = kind;
        root.statusText = text;
    }

    function setFingerprint(state, hint) {
        root.fingerprintState = state;
        root.fingerprintHint = hint !== undefined ? hint : "";
    }

    function setCapsLock(value) {
        root.capsLock = value === true;
    }

    function toggleCapsLock() {
        root.capsLock = !root.capsLock;
    }

    function resetAuth() {
        root.unlocking = false;
        root.authenticating = false;
        root.failedAttempts = 0;
        root.statusKind = "idle";
        root.statusText = "";
        root.capsLock = false;
        root.fingerprintState = "checking";
        root.fingerprintHint = "";
        root.fingerprintDevice = "";
    }

    function writeFlag(value) {
        try {
            stateFile.setText(value ? "locked\n" : "");
        } catch (error) {
            // Не сорвать блокировку из-за прав на каталог: сама блокировка
            // уже действует, теряется только защита от hot reload.
            console.warn("[lock] не записал " + root.statePath + ": " + error);
        }
    }
}
