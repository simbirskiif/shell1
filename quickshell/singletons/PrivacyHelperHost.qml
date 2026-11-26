import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Владелец процесса helper'а конфиденциальности (камера V4L2 и GeoClue2).
//
// Process нельзя держать в pragma Singleton — он там не запускается (та же
// причина, что у BluetoothHelperHost), поэтому процесс живёт в дереве
// оболочки, а разобранное состояние складывает в PrivacyService.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    // Перезапуск после падения: задержка растёт, пока helper снова не
    // ответит строкой протокола.
    property int restartDelayMs: 1000
    readonly property int restartDelayMaxMs: 10000

    readonly property string scriptPath: Quickshell.shellDir + "/scripts/qs-privacy-helper.py"

    // Очередь потоков на уничтожение: pw-cli destroy принимает один id за
    // запуск, а у приложения может быть несколько потоков.
    property var stopQueue: []

    Connections {
        target: PrivacyService

        function onStopStreamsRequested(streamIds) {
            root.destroyStreams(streamIds);
        }
    }

    function destroyStreams(ids) {
        if (!Array.isArray(ids) || ids.length === 0)
            return;
        root.stopQueue = root.stopQueue.concat(ids);
        root.runNextStop();
    }

    function runNextStop() {
        if (stopProcess.running || root.stopQueue.length === 0)
            return;
        const queue = root.stopQueue.slice();
        const id = queue.shift();
        root.stopQueue = queue;
        stopProcess.command = ["pw-cli", "destroy", String(id)];
        stopProcess.running = true;
    }

    Process {
        id: stopProcess

        running: false

        stderr: SplitParser {
            onRead: line => console.warn("[privacy-stop] " + line)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[privacy-stop] pw-cli destroy завершился с кодом " + exitCode);
            root.runNextStop();
        }
    }

    Process {
        id: helperProcess

        command: ["python3", root.scriptPath]
        running: true

        stdout: SplitParser {
            onRead: line => {
                root.restartDelayMs = 1000;
                PrivacyService.consumeHelperLine(line);
            }
        }

        stderr: SplitParser {
            onRead: line => console.warn("[privacy-helper] " + line)
        }

        onExited: (exitCode, exitStatus) => {
            // Иначе индикатор «камера используется» останется гореть после
            // падения helper'а.
            PrivacyService.clearHelperState();
            restartTimer.interval = root.restartDelayMs;
            restartTimer.restart();
            root.restartDelayMs = Math.min(root.restartDelayMs * 2,
                                           root.restartDelayMaxMs);
            console.warn("[privacy-helper] процесс завершился (код " + exitCode
                         + "), перезапуск через " + restartTimer.interval + " мс");
        }
    }

    Timer {
        id: restartTimer
        repeat: false
        onTriggered: helperProcess.running = true
    }
}
