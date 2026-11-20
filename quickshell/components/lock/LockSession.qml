import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../singletons"

// Экран блокировки сессии (ext_session_lock_v1).
//
// WlSessionLock создаёт по одному WlSessionLockSurface на каждый экран,
// когда LockState.locked становится true. Снятие блокировки — только через
// LockState.finishUnlock(): после успешной аутентификации LockState.unlocking
// запускает анимацию, и по её окончании здесь снимается locked.
//
// Корень — обычный Item, а не сам WlSessionLock: у WlSessionLock default-
// свойство — surface (Component), поэтому ЛЮБОЙ дочерний объект (Timer,
// Connections) попал бы в surface вместо поверхности, и блокировка
// прерывалась бы с «surface does not create a WlSessionLockSurface».
// Поэтому WlSessionLock — единственный ребёнок, а служебные объекты рядом.
//
// ВАЖНО: если этот объект уничтожить без locked = false, композитор оставит
// сессию заблокированной (так работает протокол). Никаких путей, которые
// снимают блокировку в обход LockState, быть не должно.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    WlSessionLock {
        id: sessionLock

        // Стабильный id помогает Reloadable-механизму Quickshell сопоставить
        // блокировку при hot reload конфига.
        reloadableId: "session-lock"

        locked: LockState.locked

        onSecureChanged: LockState.secure = sessionLock.secure

        // Поверхность — единственный ребёнок: default-свойство surface имеет
        // тип Component, и QML сам оборачивает объект в компонент.
        WlSessionLockSurface {
            id: lockSurface

            // Цвет до создания контента: базовая поверхность темы, чтобы
            // композитор не показал кадр рабочего стола, пока QML ещё
            // строится (жёсткий чёрный здесь не нужен — роль даёт нужный
            // тон и в светлой, и в тёмной схеме).
            color: Theme.surface

            LockSurface {
                anchors.fill: parent
            }
        }
    }

    Timer {
        id: releaseTimer

        // Чуть дольше анимации контента (motionMedium2), чтобы fade успел
        // закончиться до уничтожения поверхностей.
        interval: Theme.motionMedium2 + 80
        repeat: false
        onTriggered: LockState.finishUnlock()
    }

    Connections {
        target: LockState

        function onUnlockingChanged() {
            if (LockState.unlocking)
                releaseTimer.restart();
            else
                releaseTimer.stop();
        }

        function onLockedChanged() {
            if (!LockState.locked)
                releaseTimer.stop();
        }
    }
}
