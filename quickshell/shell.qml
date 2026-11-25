// Точка входа конфигурации Quickshell.
// По одному бару на каждый экран; сам бар живёт в components/Bar.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit
import "components"
import "components/dock"
import "singletons"
import "widgets/desktop"
import "widgets/core"
import "components/settings"
import "components/lock"

ShellRoot {
    id: shellRoot

    // Variable-шрифт зарезервирован для M3 Expressive (см. Theme.fontFamilyExpressive).
    FontLoader {
        id: robotoFlex
        source: "fonts/RobotoFlex.ttf"
    }

    // Владелец процесса BlueZ-helper'а: Process должен жить в дереве оболочки
    // (внутри синглтона он не запускается). Сразу подключаем его к бэкенду.
    BluetoothHelperHost {
        id: bluetoothHelperHost
    }

    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Нижний док: по одному на экран, показывается при наведении на зону
    // активации у нижней кромки. Состояние — в DockState, IPC target "dock".
    Variants {
        model: Quickshell.screens

        delegate: DockWindow {
            required property var modelData
            dockScreen: modelData
        }
    }

    // Рабочий стол с виджетами: второй слой под окнами, часть этой же
    // оболочки. Стили/палитра — из общего Theme (Wal), IPC target "widgets".
    Variants {
        model: Quickshell.screens

        delegate: DesktopLayer {
            required property var modelData
            screen: modelData
        }
    }

    WidgetIpc {}

    // Экран блокировки: состояние в LockState, процессы аутентификации
    // (PAM и fprintd) — в LockAuth, сами поверхности — в LockSession.
    // Оба объекта обязаны быть в дереве оболочки ровно в одном экземпляре.
    LockAuth {
        id: lockAuth
    }

    LockSession {
        id: lockSession
    }

    // Всплывающие индикаторы громкости и яркости — по одному на экран;
    // показывается только тот, что на экране с фокусом.
    Variants {
        model: Quickshell.screens

        delegate: OsdWindow {
            required property var modelData
            screen: modelData
        }
    }

    // Агент аутентификации Polkit. Слушатель D-Bus ровно один на сессию,
    // поэтому объект объявлен здесь, а не в диалоге на каждом экране.
    PolkitAgent {
        id: polkitAgent
    }

    // Запрос Polkit — модальным окном на экране с фокусом. Отдельная
    // поверхность нужна из-за клавиатурного фокуса (см. PolkitDialog.qml).
    Variants {
        model: Quickshell.screens

        delegate: PolkitDialog {
            required property var modelData
            dialogScreen: modelData
            agent: polkitAgent
        }
    }

    // Сервер уведомлений (D-Bus org.freedesktop.Notifications). Живёт в дереве
    // оболочки, как и Process у Bluetooth; состояние — в NotificationService.
    NotificationServer {
        id: notificationServer

        // Уведомления переживают перезагрузку конфига, иначе они пропадали бы
        // при каждом hot reload.
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => NotificationService.add(notification)
    }

    // Тосты — правый верхний угол экрана с фокусом.
    Variants {
        model: Quickshell.screens

        delegate: NotificationPopups {
            required property var modelData
            popupScreen: modelData
        }
    }

    // Центр уведомлений — панель справа, по одному окну на экран.
    Variants {
        model: Quickshell.screens

        delegate: NotificationCenter {
            required property var modelData
            centerScreen: modelData
        }
    }

    // Единое окно настроек оболочки: разделы «Бар», «Быстрые настройки»,
    // «Док», «Уведомления», «Кофеин», «Виджеты» и «Оформление». Открывается
    // из быстрых настроек, дока, меню рабочего стола и по IPC.
    Variants {
        model: Quickshell.screens

        delegate: SettingsWindow {
            required property var modelData
            settingsScreen: modelData
        }
    }

    // Выбор профиля Hyprland — оверлей по центру экрана с фокусом.
    // Список и текущий профиль читает ProfileState (файл состояния +
    // каталог профилей), переключение — через hypr-profile.
    Variants {
        model: Quickshell.screens

        delegate: ProfileSwitcher {
            required property var modelData
            pickerScreen: modelData
        }
    }

    // Просмотр окон — оверлей со списком (SUPER+TAB).
    Variants {
        model: Quickshell.screens

        delegate: WindowSwitcher {
            required property var modelData
            pickerScreen: modelData
        }
    }

    // Alt+Tab приходит из Hyprland как global shortcuts: пресает бинд,
    // отпускание Alt — release-бинд. Оверлей клавиатуру не забирает.
    GlobalShortcut {
        appid: "quickshell"
        name: "altTabNext"
        onPressed: WindowState.step(1)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "altTabPrev"
        onPressed: WindowState.step(-1)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "altTabRelease"
        onReleased: WindowState.release()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "altTabCancel"
        onPressed: WindowState.cancel()
    }

    // Окна снаружи:
    //   qs ipc -p ~/shell/quickshell call windows toggle
    IpcHandler {
        target: "windows"

        function toggle(): string {
            if (WindowState.active)
                WindowState.release();
            else
                WindowState.step(1);
            return state();
        }

        function open(): string {
            WindowState.step(1);
            return state();
        }

        function close(): string {
            WindowState.cancel();
            return state();
        }

        // Шаг по списку (1 вперёд, -1 назад).
        function cycle(delta: int): string {
            WindowState.step(delta);
            return state();
        }

        // Отпускание Alt: перейти к выбранному окну.
        function commit(): string {
            WindowState.release();
            return state();
        }

        function release(): string {
            WindowState.release();
            return state();
        }

        function cancel(): string {
            WindowState.cancel();
            return state();
        }

        function next(): string {
            WindowState.step(1);
            return state();
        }

        function prev(): string {
            WindowState.step(-1);
            return state();
        }

        function activate(): string {
            WindowState.release();
            return state();
        }

        function list(): string {
            WindowState.refresh();
            return state();
        }

        function state(): string {
            return WindowState.summary();
        }
    }

    // Плитка Layout в быстрых настройках и IPC для проверки.
    IpcHandler {
        target: "layout"

        function open(): string {
            UiState.openDetail("layout");
            return state();
        }

        function cycle(): string {
            ProfileState.next();
            return state();
        }

        function state(): string {
            return ProfileState.current;
        }
    }

    // Профили Hyprland снаружи (в том числе из бинда в профиле):
    //   qs ipc -p ~/shell/quickshell call profiles toggle
    //   qs ipc -p ~/shell/quickshell call profiles switchTo work
    IpcHandler {
        target: "profiles"

        function toggle(): string {
            ProfileState.toggle();
            return state();
        }

        function open(): string {
            ProfileState.setOpen(true);
            return state();
        }

        function close(): string {
            ProfileState.close();
            return state();
        }

        function switchTo(name: string): string {
            ProfileState.switchTo(name);
            return state();
        }

        function next(): string {
            ProfileState.next();
            return state();
        }

        function list(): string {
            ProfileState.refresh();
            return ProfileState.profiles.join(" ");
        }

        function state(): string {
            return ProfileState.summary();
        }
    }

    // Окно настроек снаружи:
    //   qs ipc -p ~/shell/quickshell call settings open dock
    //   qs ipc -p ~/shell/quickshell call settings toggle dock
    // section: bar | quick | dock | notifications | caffeine | widgets | appearance.
    IpcHandler {
        target: "settings"

        function open(section: string): string {
            SettingsWindowState.show(section, "");
            return state();
        }

        function toggle(section: string): string {
            SettingsWindowState.toggle(section, "");
            return state();
        }

        function close(): string {
            SettingsWindowState.close();
            return state();
        }

        function section(name: string): string {
            SettingsWindowState.setSection(name);
            return state();
        }

        function list(): string {
            const parts = [];
            for (let i = 0; i < SettingsWindowState.sections.length; ++i)
                parts.push(SettingsWindowState.sections[i].key);
            return parts.join(" ");
        }

        function state(): string {
            return SettingsWindowState.summary();
        }
    }

    // Экран блокировки снаружи:
    //   qs ipc -p ~/shell/quickshell call lock lock
    // Блокировка снимается только после успешного пароля или отпечатка —
    // метода unlock здесь намеренно нет.
    IpcHandler {
        target: "lock"

        function lock(): string {
            LockState.lock();
            return state();
        }

        function state(): string {
            return "locked=" + (LockState.locked ? "yes" : "no")
                + " secure=" + (LockState.secure ? "yes" : "no")
                + " auth=" + (LockState.authenticating ? "checking" : "idle")
                + " fp=" + LockState.fingerprintState
                + " fpDevice=" + (LockState.fingerprintDevice === "" ? "-" : LockState.fingerprintDevice)
                + " attempts=" + LockState.failedAttempts
                + " caps=" + (LockState.capsLock ? "on" : "off")
                + " status=" + (LockState.statusText === "" ? "-" : LockState.statusText);
        }
    }

    // Управление уведомлениями снаружи:
    //   qs ipc -p ~/shell/quickshell call notifications toggle
    IpcHandler {
        target: "notifications"

        function toggle(): string {
            NotificationService.toggleCenter();
            return state();
        }

        function open(): string {
            NotificationService.openCenter();
            return state();
        }

        function close(): string {
            NotificationService.closeCenter();
            return state();
        }

        function clear(): string {
            NotificationService.clearHistory();
            return state();
        }

        // Режим «не беспокоить»: история пишется, тостов нет.
        function dnd(): string {
            NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
            return state();
        }

        // Чувствительность горизонтального свайпа (0.5..3.0).
        function sensitivity(v: real): string {
            NotificationService.swipeSensitivity = Math.max(0.1, v);
            return state();
        }

        function state(): string {
            return NotificationService.summary();
        }
    }

    // Сервер отдаёт пережившие reload уведомления только после того, как
    // создан, поэтому связываем его с состоянием здесь.
    Component.onCompleted: NotificationService.attach(notificationServer)

    // Нижний док снаружи: qs ipc -p ~/shell/quickshell call dock <функция>.
    // enter/leave дублируют наведение для проверки анимаций без мыши.
    IpcHandler {
        target: "dock"

        function show(): string {
            DockState.show(UiState.defaultScreen());
            return state();
        }

        function hide(): string {
            DockState.hide();
            return state();
        }

        function expand(): string {
            DockState.expand(UiState.defaultScreen(), true);
            return state();
        }

        function collapse(): string {
            DockState.collapse();
            return state();
        }

        function toggle(): string {
            DockState.toggle(UiState.defaultScreen(), true);
            return state();
        }

        function enter(): string {
            DockState.pointerEntered(UiState.defaultScreen());
            return state();
        }

        function leave(): string {
            DockState.pointerExited();
            return state();
        }

        // Размер иконок (20..44) и множитель прокрутки (0.4..2.5).
        function iconSize(value: real): string {
            DockSettings.setIconSize(value);
            return state();
        }

        function scroll(value: real): string {
            DockSettings.setScrollFactor(value);
            return state();
        }

        // Сторона кнопки раскрытия: left | right.
        function buttonSide(side: string): string {
            DockSettings.setButtonSide(side);
            return state();
        }

        // Поисковый запрос в списке приложений.
        function search(text: string): string {
            DockState.query = text;
            return state();
        }

        // Elephant: включить/выключить и переключить провайдера.
        function elephant(enabled: bool): string {
            DockSearch.setElephantEnabled(enabled);
            return state();
        }

        function provider(name: string): string {
            DockSearch.toggleProvider(name);
            return state();
        }

        function probe(): string {
            DockSearch.refresh();
            return state();
        }

        // Вид списка и геометрия панели для проверки без мыши.
        function tile(enabled: bool): string {
            DockSettings.setTileLayout(enabled);
            return state();
        }

        function searchSize(value: int): string {
            DockSettings.setSearchHeight(value);
            return state();
        }

        function searchPos(where: string): string {
            DockSettings.setSearchAtBottom(where === "bottom");
            return state();
        }

        function panelHeight(value: int): string {
            DockSettings.setPanelMaxHeight(value);
            return state();
        }

        function fit(enabled: bool): string {
            DockSettings.setFitPanelToContent(enabled);
            return state();
        }

        function reset(): string {
            DockSettings.reset();
            return state();
        }

        // Настройки дока теперь в общем окне настроек. Имя функции оставлено
        // прежним: на него завязаны бинды и скрипты проверки.
        function toggleSettings(): string {
            if (SettingsWindowState.opened && SettingsWindowState.section === "dock") {
                SettingsWindowState.close();
            } else {
                DockState.collapse();
                SettingsWindowState.show("dock", DockState.screenName);
            }
            return state();
        }

        function state(): string {
            return DockState.summary
                + " icon=" + DockSettings.iconSize
                + " scroll=" + DockSettings.scrollFactor.toFixed(2)
                + " button=" + DockSettings.buttonSide
                + " tile=" + (DockSettings.tileLayout ? "on" : "off")
                + " search=" + DockSettings.searchHeight + "/"
                             + (DockSettings.searchAtBottom ? "bottom" : "top")
                + " panelMax=" + DockSettings.panelMaxHeight
                + " fit=" + (DockSettings.fitPanelToContent ? "on" : "off")
                + " " + DockSearch.summary;
        }
    }

    // Управление снаружи: qs ipc -p ~/shell/quickshell call bar <функция>.
    // Удобно повесить на бинд в Hyprland, например:
    //   bind = SUPER, A, exec, qs ipc -p ~/shell/quickshell call bar toggle
    IpcHandler {
        target: "bar"

        function toggle(): string {
            UiState.toggle(UiState.defaultScreen());
            return state();
        }

        function main(): string {
            UiState.open(UiState.defaultScreen(), "");
            return state();
        }

        function bluetooth(): string {
            UiState.open(UiState.defaultScreen(), "bluetooth");
            return state();
        }

        function internet(): string {
            UiState.open(UiState.defaultScreen(), "internet");
            return state();
        }

        // Прежнее имя панели Wi-Fi, теперь это «Интернет».
        function wifi(): string {
            return internet();
        }

        // Яркость основного экрана: погасить и вернуть прежнюю.
        function toggleBrightness(): string {
            BrightnessService.togglePrimary();
            return state();
        }

        // Режим питания: переключить по имени (проверка без мыши).
        // Значения: saver | balanced | performance.
        function profile(name: string): string {
            PowerService.setProfileByName(name);
            return power();
        }

        // Полное состояние питания: батарея, режим, доступность демона.
        function power(): string {
            return "profiles=" + (PowerService.profilesAvailable ? "ok" : "down")
                + " profile=" + PowerService.profileName
                + " perf=" + (PowerService.hasPerformanceProfile ? "yes" : "no")
                + " degraded=" + (PowerService.degradationText || "-")
                + " hold=" + (PowerService.holdsText || "-")
                + " present=" + (PowerService.present ? "yes" : "no")
                + " battery=" + PowerService.level + "%"
                + " state=" + PowerService.stateText
                + " time=" + (PowerService.timeText || "-")
                + " energy=" + PowerService.energy.toFixed(1) + "/"
                              + PowerService.energyCapacity.toFixed(1) + "Wh"
                + " rate=" + PowerService.powerDraw.toFixed(1) + "W"
                + " health=" + (PowerService.health >= 0 ? PowerService.health + "%" : "-")
                + " model=" + (PowerService.model || "-")
                + " ac=" + (PowerService.onAc ? "yes" : "no");
        }

        // Заново проверить доступность power-profiles-daemon.
        function probePower(): string {
            PowerService.probeProfiles();
            return power();
        }

        // Переключатели радио — удобно для проверки состояний.
        function toggleWifi(): string {
            NetworkService.toggleWifi();
            NetworkService.scanWifi();
            return state();
        }

        // Явные состояния radio (проверка без гонки с оптимистичным UI).
        function wifiOn(): string {
            NetworkService.setWifiEnabled(true);
            NetworkService.scanWifi();
            return state();
        }

        function wifiOff(): string {
            NetworkService.setWifiEnabled(false);
            return state();
        }

        function toggleBluetooth(): string {
            BluetoothBackend.toggleEnabled();
            return state();
        }

        // Обновить список сетей (скан).
        function scanWifi(): string {
            NetworkService.scanWifi();
            return state();
        }

        // Подключение/отключение сети по имени из моделей сервиса.
        function wifiConnect(name: string): string {
            NetworkService.requestWifi(name);
            return state();
        }

        // То же по индексу в списке доступных сетей (для скриптов).
        function wifiConnectIndex(index: int): string {
            const model = NetworkService.wifiNetworks.count > 0
                        ? NetworkService.wifiNetworks : NetworkService.savedWifiNetworks;
            const network = model.get(index);
            if (network)
                NetworkService.requestWifi(network.name);
            return state();
        }

        function password(value: string): string {
            NetworkService.pendingPassword = value;
            return state();
        }

        function submitPassword(value: string): string {
            NetworkService.submitPassword(value !== "" ? value : NetworkService.pendingPassword);
            return state();
        }

        function cancelPassword(): string {
            NetworkService.cancelPending();
            return state();
        }

        function openPortal(): string {
            NetworkService.openPortal();
            return state();
        }

        // Контекстное меню сохранённой сети (проверка без мыши):
        // открыть по имени, сменить пароль, забыть.
        function menu(name: string): string {
            if (UiState.openedScreen === "")
                UiState.open(UiState.defaultScreen(), "internet");
            UiState.panel = "internet";
            // Позиция как у настоящего правого клика по строке Saved:
            // координаты внутри окна панели.
            UiState.openNetworkMenu(name, Math.round(UiState.popupHeight * 0.35), 60);
            return menuState();
        }

        function changePassword(name: string): string {
            NetworkService.changePassword(name);
            return state();
        }


        function forget(): string {
            NetworkService.beginForget(UiState.menuNetwork);
            return menuState();
        }

        function confirmForget(): string {
            NetworkService.confirmForget();
            return menuState();
        }

        function cancelForget(): string {
            NetworkService.cancelForget();
            return menuState();
        }

        function menuState(): string {
            return "menu=" + (UiState.menuNetwork === "" ? "no" : UiState.menuNetwork)
                + " forget=" + (NetworkService.forgetPending === "" ? "no" : NetworkService.forgetPending)
                + " passwordChange=" + (NetworkService.passwordChange ? "yes" : "no")
                + " pending=" + (NetworkService.pendingNetwork === "" ? "no" : NetworkService.pendingNetwork)
                + " err=" + (NetworkService.connectError || "-");
        }

        // Список сетей и профилей — для проверки без мыши и скриншотов.
        function networks(): string {
            const parts = [];
            for (let i = 0; i < NetworkService.savedWifiNetworks.count; ++i) {
                const n = NetworkService.savedWifiNetworks.get(i);
                parts.push("saved[" + i + "]=" + n.name + "/" + n.security
                           + (n.connected ? "/on" : "") + (n.connecting ? "/..." : ""));
            }
            for (let i = 0; i < NetworkService.wifiNetworks.count; ++i) {
                const n = NetworkService.wifiNetworks.get(i);
                parts.push("avail[" + i + "]=" + n.name + "/" + n.security + "/sig" + n.strength
                           + (n.connected ? "/on" : "") + (n.connecting ? "/..." : ""));
            }
            return parts.join(" ");
        }

        // Подробности для отладки: устройство, маршрут, скорость.
        function net(): string {
            return "dev=" + (NetworkService.wifiDev || "-")
                + " state=" + (NetworkService.wifiDevState || "-")
                + " hw=" + NetworkService.wifiHardBlocked
                + " wiredDev=" + (NetworkService.ethernetName || "-")
                + " wiredState=" + (NetworkService.ethernetState || "-")
                + " speed=" + (NetworkService.ethernetSpeed || "-")
                + " route=" + (NetworkService.defaultRouteDev || "-")
                + " connectivity=" + NetworkService.connectivity;
        }

        function ethernet(): string {
            NetworkService.requestEthernet();
            return state();
        }

        // Жест «назад»: сдвинуть/завершить (для проверки без тачпада).
        function swipe(delta: real): string {
            UiState.swipeBy(delta, Theme.quickWidth);
            return state();
        }

        function endSwipe(): string {
            UiState.endSwipe();
            return state();
        }

        function discoverable(): string {
            BluetoothBackend.toggleDiscoverable();
            return state();
        }

        // Заново запустить поиск сетей и устройств.
        function rescan(): string {
            NetworkService.scanWifi();
            BluetoothBackend.startScan();
            return state();
        }

        function brightness(): string {
            UiState.open(UiState.defaultScreen(), "brightness");
            return state();
        }

        // Кофеин: открыть панель выбора срока.
        function caffeine(): string {
            UiState.open(UiState.defaultScreen(), "caffeine");
            return state();
        }

        // Режим кофеина: off | 30 | 60 | 120 | infinite.
        function caffeineMode(mode: string): string {
            CaffeineService.setMode(mode);
            return state();
        }

        // Кружок плитки: бесконечно вкл/выкл.
        function caffeineToggle(): string {
            CaffeineService.toggle();
            return state();
        }

        // Яркость каждого экрана: список целей и текущие значения.
        function displays(): string {
            const parts = [];
            for (let i = 0; i < BrightnessService.targets.length; ++i) {
                const target = BrightnessService.targets[i];
                parts.push("screen[" + i + "]=" + target.label
                    + "/" + (target.method || "none")
                    + (target.controllable
                       ? "/" + Math.round(BrightnessService.valueFor(target.key) * 100) + "%"
                       : "/" + target.hint));
            }
            return parts.join(" ");
        }

        // Проверка без мыши: яркость основного экрана и конкретного экрана.
        function setBrightness(value: real): string {
            if (BrightnessService.primary !== null)
                BrightnessService.setValue(BrightnessService.primary.key, value);
            return displays();
        }

        function screenBrightness(index: int, value: real): string {
            const target = BrightnessService.targets[index];
            if (target)
                BrightnessService.setValue(target.key, value);
            return displays();
        }

        // Порядок элементов бара: сдвинуть первый в конец (для проверки).
        function rotateBarItems(): string {
            MockState.rotateBarItems();
            return state();
        }

        // Состояние настроек: файл, ключи и то, что сейчас в памяти.
        function settingsState(): string {
            const bar = [];
            for (let i = 0; i < MockState.barItems.count; ++i)
                bar.push(MockState.barItems.get(i).itemKey);
            return "path=" + Settings.path
                + " loaded=" + Settings.loaded
                + " keys=" + Object.keys(Settings.values).join("|")
                + " caffeine=" + CaffeineService.mode
                + " last=" + CaffeineService.lastMode
                + " durations=[" + CaffeineService.durations + "]"
                + " tiles=" + MockState.visibleTiles.join(",")
                + " available=" + MockState.availableTiles.join(",")
                + " bar=" + bar.join(",")
                + " barPercent=" + (MockState.showBatteryPercent ? "on" : "off")
                + " dnd=" + (NotificationService.doNotDisturb ? "on" : "off")
                + " sens=" + NotificationService.swipeSensitivity.toFixed(2)
                + " soundTab=" + UiState.soundTab;
        }

        // Строка длительностей кофеина: проверить без мыши можно и так.
        function caffeineDurations(text: string): string {
            CaffeineService.durations = text;
            return settingsState();
        }

        // Открыть окно правки длительностей и подтвердить ввод (без мыши).
        function caffeineEdit(): string {
            UiState.requestInput("caffeine.durations", "Длительности кофеина",
                                 "Например: 30, 1h, 2h 30m. Число без единицы — минуты.",
                                 CaffeineService.durations);
            return state();
        }

        function caffeineSubmit(text: string): string {
            UiState.submitInput(text);
            return settingsState();
        }

        // Настройка бара: показывать ли процент батареи.
        function toggleBarBattery(): string {
            MockState.showBatteryPercent = !MockState.showBatteryPercent;
            return state();
        }

        // Режим редактирования плиток: вход, сохранить, отменить.
        function edit(): string {
            UiState.open(UiState.defaultScreen(), "");
            UiState.beginEdit();
            return state();
        }

        function saveEdit(): string {
            UiState.saveEdit();
            return state();
        }

        function cancelEdit(): string {
            UiState.cancelEdit();
            return state();
        }

        // Операции редактора (проверка без мыши): скрыть/вернуть/переставить.
        function hideTile(index: int): string {
            UiState.hideTile(UiState.draftVisible[index]);
            return state();
        }

        function showTile(index: int): string {
            UiState.showTile(UiState.draftAvailable[index]);
            return state();
        }

        function moveTile(from: int, to: int): string {
            UiState.moveTile(from, to);
            return state();
        }

        // Шестерёнка быстрых настроек ведёт в общее окно настроек.
        function settings(): string {
            SettingsWindowState.show("bar", "");
            return state();
        }

        function battery(): string {
            UiState.open(UiState.defaultScreen(), "battery");
            return state();
        }

        function sound(): string {
            UiState.open(UiState.defaultScreen(), "sound");
            return state();
        }

        // Панель выбора устройств: kind "output" или "input".
        function soundDevices(kind: string): string {
            UiState.open(UiState.defaultScreen(),
                         kind === "input" ? "sound-input" : "sound-output");
            return state();
        }

        // Вкладка панели «Звук»: "output" (динамики) или "input" (микрофон).
        function soundTab(key: string): string {
            UiState.setSoundTab(key);
            return state();
        }

        // Состояние звука: устройства по умолчанию, их громкость и mute,
        // списки устройств и потоки приложений.
        function audio(): string {
            const out = [];
            out.push("ready=" + AudioService.available
                + " out=" + (AudioService.outputName || "-")
                + " outVol=" + Math.round(AudioService.outputVolume * 100)
                + " outMuted=" + (AudioService.outputMuted ? "yes" : "no")
                + " in=" + (AudioService.inputName || "-")
                + " inVol=" + Math.round(AudioService.inputVolume * 100)
                + " inMuted=" + (AudioService.inputMuted ? "yes" : "no"));
            for (let i = 0; i < AudioService.outputDevices.length; ++i) {
                const device = AudioService.outputDevices[i];
                out.push("out[" + i + "]=" + AudioService.deviceLabel(device)
                    + (AudioService.isDefaultSink(device) ? "/on" : ""));
            }
            for (let i = 0; i < AudioService.inputDevices.length; ++i) {
                const device = AudioService.inputDevices[i];
                out.push("in[" + i + "]=" + AudioService.deviceLabel(device)
                    + (AudioService.isDefaultSource(device) ? "/on" : ""));
            }
            for (let i = 0; i < AudioService.streams.length; ++i) {
                const stream = AudioService.streams[i];
                out.push("stream[" + i + "]=" + AudioService.streamLabel(stream)
                    + "/vol" + Math.round(stream.audio.volume * 100)
                    + (stream.audio.muted ? "/muted" : ""));
            }
            return out.join(" ");
        }

        // Проверка без мыши: громкость и mute вывода и входа.
        function volume(value: real): string {
            AudioService.setOutputVolume(value);
            return audio();
        }

        function inputVolume(value: real): string {
            AudioService.setInputVolume(value);
            return audio();
        }

        function muteOutput(): string {
            AudioService.toggleOutputMute();
            return audio();
        }

        function muteInput(): string {
            AudioService.toggleInputMute();
            return audio();
        }

        // Выбор устройства по индексу в списке устройств.
        function selectOutput(index: int): string {
            AudioService.setDefaultSink(AudioService.outputDevices[index]);
            return audio();
        }

        function selectInput(index: int): string {
            AudioService.setDefaultSource(AudioService.inputDevices[index]);
            return audio();
        }

        // Громкость и mute потока приложения по индексу в списке потоков.
        function streamVolume(index: int, value: real): string {
            AudioService.setNodeVolume(AudioService.streams[index], value);
            return audio();
        }

        function streamMute(index: int): string {
            const stream = AudioService.streams[index];
            if (stream)
                AudioService.setNodeMuted(stream, !stream.audio.muted);
            return audio();
        }

        function close(): string {
            UiState.close();
            return state();
        }

        // Демо-строки: посмотреть анимации появления/удаления в списках.
        function addWifi(): string {
            NetworkService.addDemoNetwork();
            return state();
        }

        function removeWifi(): string {
            NetworkService.removeDemoNetwork();
            return state();
        }

        // Включить/выключить видимость Bluetooth-адаптера.
        function bluetoothDiscoverable(): string {
            BluetoothBackend.toggleDiscoverable();
            return state();
        }

        // Запустить/остановить поиск Bluetooth-устройств.
        function bluetoothScan(): string {
            BluetoothBackend.toggleScan();
            return state();
        }

        // Принудительно перечитать палитру pywal и активные обои.
        function palette(): string {
            Wal.reload();
            Wallpaper.reload();
            return state();
        }

        function state(): string {
            const order = [];
            const tiles = (UiState.editing ? UiState.draftVisible : MockState.visibleTiles).join(",");
            for (let i = 0; i < MockState.barItems.count; ++i)
                order.push(MockState.barItems.get(i).itemKey);
            return "opened=" + (UiState.openedScreen === "" ? "no" : UiState.openedScreen)
                + " panel=" + (UiState.panel === "" ? "main" : UiState.panel)
                + " palette=" + (Wal.walLoaded ? "wal" : "fallback")
                + " bg=" + Wal.background + " accent=" + Wal.accent
                + " brightness=" + BrightnessService.summary
                + " screens=" + BrightnessService.targets.length
                + " caffeine=" + CaffeineService.mode
                + " h=" + Math.round(UiState.popupHeight)
                + " tiles=" + tiles + (UiState.editing ? " [edit]" : "")
                + " netTile=" + (NetworkService.internetViaEthernet ? "Internet" : "Wi-Fi")
                + " order=" + order.join(",")
                + " barPercent=" + (MockState.showBatteryPercent ? "on" : "off")
                + " battery=" + PowerService.level + "%" + (PowerService.charging ? "+" : "")
                + " out=" + Math.round(AudioService.outputVolume * 100) + "%"
                             + (AudioService.outputMuted ? "m" : "")
                + " in=" + Math.round(AudioService.inputVolume * 100) + "%"
                            + (AudioService.inputMuted ? "m" : "")
                + " streams=" + AudioService.streams.length
                + " soundTab=" + UiState.soundTab
                + " mode=" + PowerService.profileName
                + " profiles=" + (PowerService.profilesAvailable ? "ok" : "down")
                + " eth=" + (NetworkService.ethernetConnected
                             ? (NetworkService.internetViaEthernet ? "active" : "idle") : "off")
                + " ethName=" + (NetworkService.ethernetName || "-")
                + " ethSpeed=" + (NetworkService.ethernetSpeed || "-")
                + " scanning=" + (NetworkService.wifiScanning || BluetoothBackend.scanning)
                + " swipe=" + UiState.swipe.toFixed(2)
                + " pending=" + (NetworkService.pendingNetwork === "" ? "no" : NetworkService.pendingNetwork)
                + " connecting=" + (NetworkService.connectingName || BluetoothBackend.busyAddress || "no")
                + " err=" + (NetworkService.connectError || "-")
                + " connectivity=" + NetworkService.connectivity
                + " backend=" + (NetworkService.backendAvailable ? "ok" : "down")
                + " radio=" + (NetworkService.wifiEnabled ? "on" : "off")
                + " hwblock=" + (NetworkService.wifiHardBlocked ? "yes" : "no")
                + " discoverable=" + (BluetoothBackend.discoverable ? "on" : "off")
                + " wifi=" + NetworkService.wifiNetworks.count
                + " saved=" + NetworkService.savedWifiNetworks.count
                + " ssid=" + (NetworkService.connectedSsid || "-")
                + " paired=" + BluetoothBackend.pairedDevices.count
                + " devices=" + BluetoothBackend.newDevices.count
                + " dock=" + DockState.phase + "/" + (DockState.screenName || "-");
        }
    }
}


