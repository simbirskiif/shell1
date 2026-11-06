import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import "../../singletons"

// Владелец процессов аутентификации экрана блокировки.
//
// Почему отдельный объект в дереве оболочки: Process и PamContext не
// запускаются из `pragma Singleton` (проверено на BlueZ-helper'е). Поэтому
// вся I/O-часть здесь, а состояние и правила — в LockState.
//
// Пароль: PAM-конфиг "login" — то же, что использует hyprlock на этой системе
// (/etc/pam.d/hyprlock включает login), вместе с pam_faillock. Пароль живёт
// только в root.pendingResponse до respond() и сразу забывается.
//
// Отпечаток: fprintd по D-Bus через scripts/qs-fprint-helper.py. PAM и сканер
// работают независимо: успех любого канала ведёт в LockState.unlockSucceeded().
// Ошибка или остановка процессов никогда не снимает блокировку.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    // Отпечаток включён для текущей блокировки и helper не остановлен вручную.
    property bool helperWanted: false
    property bool helperOnline: false
    // Helper получил quit и завершается: новый запуск ждёт его выхода.
    property bool helperStopping: false
    // Текущий ответ, который ждёт PAM. Сбрасывается сразу после respond().
    property string pendingResponse: ""
    // PAM-сессия активна; защищает от двойного start/завершения.
    property bool authInFlight: false

    readonly property string helperPath: Quickshell.shellDir + "/scripts/qs-fprint-helper.py"
    // Сколько ждём ответа PAM, прежде чем признать попытку зависшей.
    readonly property int authTimeoutMs: 15000
    // Пауза между автоматическими попытками сканера (fprintd освобождает
    // устройство не мгновенно).
    readonly property int fingerprintRetryMs: 1000

    // ── PAM ────────────────────────────────────────────────────────────

    PamContext {
        id: pam

        config: "login"
        user: LockState.userName

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.finishAttempt(true, "");
            } else if (result === PamResult.MaxTries) {
                root.finishAttempt(false, "Too many attempts, try again later");
            } else if (result === PamResult.Failed) {
                root.finishAttempt(false, "Wrong password, try again");
            } else {
                root.finishAttempt(false, "Authentication is unavailable");
            }
        }

        onError: error => {
            console.warn("[lock] PAM error: " + PamError.toString(error));
            root.finishAttempt(false, "Authentication is unavailable");
        }

        onResponseRequiredChanged: {
            if (!pam.responseRequired)
                return;
            if (!root.authInFlight) {
                pam.abort();
                return;
            }
            const response = root.pendingResponse;
            // PAM просит ответ повторно после отклонённого пароля, а нового
            // у нас нет: попытка уже провалилась, второй раз не спрашиваем.
            if (response === "") {
                pam.abort();
                root.finishAttempt(false, "Wrong password, try again");
                return;
            }
            root.pendingResponse = "";
            pam.respond(response);
        }
    }

    Timer {
        id: authTimeout

        interval: root.authTimeoutMs
        repeat: false
        running: root.authInFlight
        onTriggered: {
            if (!root.authInFlight)
                return;
            pam.abort();
            root.finishAttempt(false, "Authentication timed out");
        }
    }

    function startPassword(value) {
        if (!LockState.locked || LockState.unlocking)
            return;
        if (root.authInFlight)
            return;
        root.pendingResponse = value;
        root.authInFlight = true;
        if (!pam.start()) {
            root.pendingResponse = "";
            root.finishAttempt(false, "Authentication is unavailable");
        }
    }

    function finishAttempt(success, text) {
        if (!root.authInFlight)
            return;
        // Результат пришёл уже во время снятия блокировки: менять состояние
        // интерфейса поздно и незачем.
        if (!LockState.locked || LockState.unlocking) {
            root.authInFlight = false;
            root.pendingResponse = "";
            authTimeout.stop();
            return;
        }
        root.authInFlight = false;
        root.pendingResponse = "";
        authTimeout.stop();
        if (success) {
            LockState.unlockSucceeded();
            root.stopHelper("unlock");
            return;
        }
        LockState.passwordFailed(text);
    }

    function abortAuth() {
        if (root.authInFlight)
            pam.abort();
        root.authInFlight = false;
        root.pendingResponse = "";
        authTimeout.stop();
    }

    // ── отпечаток ──────────────────────────────────────────────────────

    Process {
        id: helper

        command: ["python3", root.helperPath]
        running: false

        stdout: SplitParser {
            onRead: line => root.handleHelperLine(line)
        }
        stderr: SplitParser {
            onRead: line => console.log("[fprint] " + line)
        }

        onStarted: helperReadyTimer.restart()

        onExited: (exitCode, exitStatus) => {
            root.helperOnline = false;
            helperReadyTimer.stop();
            if (root.helperStopping) {
                root.helperStopping = false;
                // Блокировку успели включить заново, пока helper выходил.
                if (root.helperWanted && LockState.locked)
                    root.startHelperProcess();
                return;
            }
            if (!root.helperWanted)
                return;
            // Helper штатно выходит только если устройства нет; всё
            // остальное — падение, и отпечаток до конца блокировки недоступен.
            root.helperWanted = false;
            LockState.setFingerprint("unavailable", "Fingerprint helper stopped");
            console.warn("[lock] fprint-helper завершился (код " + exitCode + ")");
        }
    }

    Timer {
        id: helperReadyTimer

        interval: 5000
        repeat: false
        onTriggered: {
            if (!root.helperWanted || root.helperOnline)
                return;
            LockState.setFingerprint("unavailable", "Fingerprint sensor is not responding");
        }
    }

    Timer {
        id: retryTimer

        interval: root.fingerprintRetryMs
        repeat: false
        onTriggered: root.startVerify()
    }

    Timer {
        id: terminateTimer

        interval: 400
        repeat: false
        onTriggered: if (helper.running) helper.running = false
    }

    function startFingerprint() {
        if (root.helperWanted)
            return;
        root.helperWanted = true;
        LockState.setFingerprint("checking");
        if (helper.running) {
            // Прошлый helper ещё не завершился: дождёмся onExited и поднимем
            // процесс заново, иначе quit из прошлой блокировки его убьёт.
            if (root.helperStopping)
                return;
            root.sendVerify();
            return;
        }
        root.startHelperProcess();
    }

    function startHelperProcess() {
        if (helper.running)
            return;
        root.helperOnline = false;
        root.helperStopping = false;
        LockState.setFingerprint("checking");
        helperReadyTimer.restart();
        helper.running = true;
    }

    function stopHelper(reason) {
        root.helperWanted = false;
        retryTimer.stop();
        helperReadyTimer.stop();
        if (!helper.running)
            return;
        root.helperStopping = true;
        helper.write("{\"cmd\":\"quit\"}\n");
        terminateTimer.start();
        console.info("[lock] отпечаток остановлен: " + reason);
    }

    function sendVerify() {
        if (!helper.running || !root.helperOnline || !root.helperWanted)
            return;
        if (!LockState.locked || LockState.unlocking)
            return;
        helper.write(JSON.stringify({ cmd: "verify", user: LockState.userName }) + "\n");
    }

    function startVerify() {
        if (!root.helperWanted)
            return;
        if (LockState.fingerprintState === "scanning")
            return;
        root.sendVerify();
    }

    function handleHelperLine(line) {
        if (line.trim().length === 0)
            return;
        let event = null;
        try {
            event = JSON.parse(line);
        } catch (error) {
            console.warn("[lock] fprint-helper: не JSON: " + line);
            return;
        }

        switch (event.ev) {
        case "ready":
            root.helperOnline = true;
            helperReadyTimer.stop();
            LockState.fingerprintDevice = event.device !== undefined ? event.device : "";
            if (!root.helperWanted || !LockState.locked || LockState.unlocking)
                return;
            LockState.setFingerprint("ready");
            root.sendVerify();
            break;

        case "scanning":
            if (!root.helperWanted)
                return;
            LockState.setFingerprint("scanning");
            break;

        case "status":
            root.handleStatus(event);
            break;

        case "unavailable":
            root.helperWanted = false;
            LockState.setFingerprint("unavailable",
                                     event.reason !== undefined ? event.reason
                                                                : "Fingerprint is unavailable");
            break;

        case "error":
            if (!root.helperWanted)
                return;
            root.helperWanted = false;
            retryTimer.stop();
            LockState.setFingerprint(event.reason === "busy" ? "busy" : "error",
                                     event.message !== undefined ? event.message
                                                                : "Fingerprint error");
            break;

        case "stopped":
            break;
        }
    }

    function handleStatus(event) {
        // После остановки (успешный вход, снятие блокировки) fprintd ещё
        // присылает хвостовой verify-no-match — он уже не имеет значения.
        if (!root.helperWanted || !LockState.locked || LockState.unlocking)
            return;

        const status = event.status;
        if (status === "verify-match") {
            LockState.unlockSucceeded();
            root.stopHelper("match");
            return;
        }
        if (status === "verify-no-match") {
            LockState.setFingerprint("retry");
            retryTimer.restart();
            return;
        }
        // Промежуточные состояния (verify-retry-scan, палец не по центру и
        // т.п.) означают, что сканер продолжает ждать палец.
        LockState.setFingerprint("scanning");
    }

    // ── Caps Lock ──────────────────────────────────────────────────────
    // Событий о состоянии Caps Lock в Quickshell 0.3.2 нет, поэтому читаем
    // состояние один раз при блокировке и после неудачной попытки, а нажатие
    // Caps Lock отслеживает LockSurface.

    Process {
        id: capsQuery

        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devices = JSON.parse(text);
                    const keyboards = devices.keyboards !== undefined ? devices.keyboards : [];
                    let enabled = false;
                    for (let i = 0; i < keyboards.length; ++i) {
                        if (keyboards[i] && keyboards[i].capsLock === true)
                            enabled = true;
                    }
                    LockState.setCapsLock(enabled);
                } catch (error) {
                    // Не Hyprland или утилита недоступна: индикатор не нужен.
                    console.info("[lock] Caps Lock неизвестен: " + error);
                }
            }
        }
    }

    function refreshCaps() {
        if (capsQuery.running)
            return;
        capsQuery.running = true;
    }

    // ── связь с состоянием ─────────────────────────────────────────────

    Connections {
        target: LockState

        function onLockedChanged() {
            if (LockState.locked) {
                root.abortAuth();
                root.refreshCaps();
                root.startFingerprint();
            } else {
                root.abortAuth();
                root.stopHelper("unlocked");
            }
        }

        function onPasswordRequested(password) {
            root.startPassword(password);
        }

        function onFingerprintRequested() {
            if (!root.helperWanted)
                root.startFingerprint();
            else
                root.startVerify();
        }

        function onCapsRefreshRequested() {
            root.refreshCaps();
        }
    }

    // LockState восстанавливает блокировку из флага на старте: locked уже
    // true до Component.onCompleted, поэтому подхватываем и его.
    Component.onCompleted: {
        if (!LockState.locked)
            return;
        root.refreshCaps();
        root.startFingerprint();
    }
}
