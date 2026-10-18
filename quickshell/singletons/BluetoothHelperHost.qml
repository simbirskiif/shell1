import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Владелец процесса BlueZ-helper'а.
//
// Почему отдельный объект в дереве оболочки: Process, объявленный или
// созданный внутри `pragma Singleton`, НЕ запускается — ни onStarted, ни
// onExited, `running` остаётся false (проверено сравнением: тот же код под
// ShellRoot работает). Поэтому процесс живёт здесь, а BluetoothBackend
// регистрируется как приёмник событий и пишет команды через write().
//
// Обязателен ровно один экземпляр: он размещается в shell.qml.
Item {
    id: root

    // Процесс запущен.
    readonly property bool running: helperProcess.running
    // helper прислал ready: можно слать команды.
    property bool online: false
    // Сколько раз helper перезапускался (для отладки).
    property int restarts: 0

    // Задержка перезапуска: удваивается до потолка и сбрасывается при ready.
    property int restartDelayMs: 1000
    readonly property int restartDelayMaxMs: 10000

    // Путь к скрипту helper'а: рядом с конфигом.
    readonly property string scriptPath: Quickshell.shellDir + "/scripts/qs-bluetooth-helper.py"

    visible: false
    width: 0
    height: 0

    // Каждая строка протокола (одно JSON-событие).
    signal lineReceived(string line)
    // Процесс завершился (перед перезапуском).
    signal stopped()

    // Отправить команду в stdin helper'а.
    function send(text) {
        if (!helperProcess.running)
            return false;
        helperProcess.write(text);
        return true;
    }

    Process {
        id: helperProcess

        command: ["python3", root.scriptPath]
        running: true

        stdout: SplitParser {
            onRead: line => root.lineReceived(line)
        }
        stderr: SplitParser {
            // Диагностика helper'а: видно в логе Quickshell.
            onRead: line => console.log("[bluez-helper] " + line)
        }

        onExited: (exitCode, exitStatus) => {
            root.online = false;
            root.stopped();
            root.restarts++;
            restartTimer.interval = root.restartDelayMs;
            restartTimer.restart();
            root.restartDelayMs = Math.min(root.restartDelayMs * 2,
                                           root.restartDelayMaxMs);
            console.log("[bluez-helper] процесс завершился (код " + exitCode
                        + "), перезапуск через " + restartTimer.interval + " мс");
        }
    }

    Timer {
        id: restartTimer
        repeat: false
        onTriggered: helperProcess.running = true
    }

    Component.onCompleted: {
        console.log("[bluez-helper] запускаю " + scriptPath);
        // Регистрируемся в бэкенде: он будет присылать команды и получит поток
        // событий через свой handleLine.
        BluetoothBackend.attachHost(root);
    }
}
