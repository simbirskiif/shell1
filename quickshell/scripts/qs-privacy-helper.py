#!/usr/bin/env python3
"""Индикатор конфиденциальности: камера (V4L2) и геолокация (GeoClue2).

Микрофон определяется в QML по потокам PipeWire (PrivacyService), здесь —
то, чего нет в API Quickshell:
  * камера: какие процессы держат открытым /dev/video*, включая приложения,
    которые работают с V4L2 напрямую, а не через PipeWire;
  * геолокация: свойство InUse менеджера GeoClue2 — сервис поднимается
    только когда приложение запросило местоположение.

stdout — протокол, по одной JSON-строке на изменение состояния:
  {"cameraAvailable":bool,"cameraActive":bool,"cameraApps":[str],
   "locationAvailable":bool,"locationActive":bool}

Демоны PipeWire/WirePlumber не считаются пользователями камеры: если камеру
заняло приложение через PipeWire, это видно по узлу-потоку в QML, а сам
сервер открывает устройство ради этого потока и дал бы ложное срабатывание.

Зависимости: python3 + dbus-python + python-gobject (пакеты python-dbus и
python-gobject в Arch). Если D-Bus недоступен, камера всё равно работает,
а геолокация остаётся недоступной.
"""

import glob
import json
import os
import signal
import sys

SERVICE = "org.freedesktop.GeoClue2"
MANAGER_PATH = "/org/freedesktop/GeoClue2/Manager"
MANAGER_IFACE = "org.freedesktop.GeoClue2.Manager"
# Опрос /proc: у ядра нет события «процесс открыл устройство». Сканирование
# дешёвое (сотни readlink), но лишний раз в секунду не нужно.
CAMERA_POLL_MS = 3000

# Процессы, которые открывают камеру как часть аудио/видео стека, а не как
# приложение-пользователь.
PIPELINE_PROCESSES = {"pipewire", "pipewire-media-session", "wireplumber", "wireplumber-hyprland"}

state = {
    "cameraAvailable": False,
    "cameraActive": False,
    "cameraApps": [],
    "locationAvailable": False,
    "locationActive": False,
}

last_snapshot = None
running = True


def publish(force=False):
    """Печатает состояние, если оно изменилось с прошлой строки."""
    global last_snapshot
    snapshot = json.dumps(state, ensure_ascii=False)
    if not force and snapshot == last_snapshot:
        return
    last_snapshot = snapshot
    print(snapshot, flush=True)


def read_process_name(pid):
    """Имя процесса для подписи в панели; пустая строка — служебный процесс."""
    try:
        with open("/proc/" + pid + "/comm", "r", encoding="utf-8") as handle:
            name = handle.read().strip()
    except OSError:
        return ""
    if not name or name in PIPELINE_PROCESSES:
        return ""
    return name


def camera_devices_present():
    try:
        if os.listdir("/sys/class/video4linux"):
            return True
    except OSError:
        pass
    return bool(glob.glob("/dev/video*"))


def camera_holders():
    """Имена процессов, у которых открыт /dev/video*."""
    holders = set()
    try:
        pids = os.listdir("/proc")
    except OSError:
        return holders

    for pid in pids:
        if not pid.isdigit():
            continue
        fd_dir = "/proc/" + pid + "/fd"
        try:
            entries = os.listdir(fd_dir)
        except OSError:
            # Чужой процесс или ядро: не наша зона ответственности.
            continue
        for entry in entries:
            try:
                target = os.readlink(fd_dir + "/" + entry)
            except OSError:
                continue
            if not target.startswith("/dev/video"):
                continue
            name = read_process_name(pid)
            if name:
                holders.add(name)
            break
    return holders


def scan_camera():
    available = camera_devices_present()
    holders = camera_holders()
    # Камера без /sys (песочница, нестандартный devtmpfs), но занятая
    # процессом, всё равно существует.
    if holders:
        available = True
    state["cameraAvailable"] = available
    state["cameraActive"] = bool(holders)
    state["cameraApps"] = sorted(holders)
    publish()


class LocationWatcher:
    """Следит за GeoClue2, не запуская сервис без причины."""

    def __init__(self):
        self.bus = None
        self.GLib = None
        self.owner = False
        self.activatable = False
        self.refresh_pending = False
        self._connect()

    def _connect(self):
        try:
            import dbus
            import dbus.mainloop.glib
            from gi.repository import GLib
        except Exception as error:  # noqa: BLE001 — модули опциональны
            print("[privacy] D-Bus недоступен: " + str(error), file=sys.stderr)
            state["locationAvailable"] = False
            state["locationActive"] = False
            publish()
            return

        self.dbus = dbus
        self.GLib = GLib
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

        try:
            self.bus = dbus.SystemBus()
        except Exception as error:  # noqa: BLE001 — нет системной шины
            print("[privacy] нет системной шины: " + str(error), file=sys.stderr)
            state["locationAvailable"] = False
            state["locationActive"] = False
            publish()
            return

        try:
            self.activatable = SERVICE in self.bus.list_activatable_names()
        except Exception:  # noqa: BLE001 — сервис просто считаем отсутствующим
            self.activatable = False
        try:
            self.owner = self.bus.name_has_owner(SERVICE)
        except Exception:  # noqa: BLE001
            self.owner = False

        # Подписка до первого чтения: иначе можно пропустить переключение
        # InUse между Get и add_signal_receiver.
        self.bus.add_signal_receiver(
            self._on_properties_changed,
            signal_name="PropertiesChanged",
            dbus_interface="org.freedesktop.DBus.Properties",
            bus_name=SERVICE,
            path=MANAGER_PATH,
        )
        self.bus.add_signal_receiver(
            self._on_name_owner_changed,
            signal_name="NameOwnerChanged",
            dbus_interface="org.freedesktop.DBus",
            arg0=SERVICE,
        )

        state["locationAvailable"] = self.activatable or self.owner
        if self.owner:
            state["locationActive"] = self._read_in_use()
        else:
            state["locationActive"] = False
        publish()

    def _read_in_use(self):
        if self.bus is None:
            return False
        try:
            value = self.bus.call_blocking(
                SERVICE, MANAGER_PATH, "org.freedesktop.DBus.Properties", "Get",
                "ss", (MANAGER_IFACE, "InUse"), timeout=2.0)
        except Exception:  # noqa: BLE001 — сервис мог остановиться между вызовами
            return False
        return bool(value)

    def _refresh(self):
        self.refresh_pending = False
        if self.bus is None:
            return False
        try:
            self.owner = self.bus.name_has_owner(SERVICE)
        except Exception:  # noqa: BLE001
            self.owner = False
        state["locationAvailable"] = self.activatable or self.owner
        state["locationActive"] = self._read_in_use() if self.owner else False
        publish()
        return False  # одноразовый таймер GLib

    def _schedule_refresh(self):
        if self.refresh_pending:
            return
        self.refresh_pending = True
        # Даём сервису договориться с шиной: NameOwnerChanged приходит чуть
        # раньше, чем объект менеджера готов отвечать.
        self.GLib.timeout_add(150, self._refresh)

    def _on_properties_changed(self, interface, changed, invalidated):
        if interface != MANAGER_IFACE:
            return
        if "InUse" not in changed:
            return
        state["locationActive"] = bool(changed["InUse"])
        publish()

    def _on_name_owner_changed(self, name, old_owner, new_owner):
        # Сигнал приходит и при смене владельца, и при остановке сервиса.
        self.owner = bool(new_owner)
        state["locationAvailable"] = self.activatable or self.owner
        if self.owner:
            self._schedule_refresh()
        else:
            state["locationActive"] = False
            publish()


def main():
    try:
        from gi.repository import GLib
    except Exception as error:  # noqa: BLE001 — python-gobject не установлен
        print("[privacy] нет GLib: " + str(error), file=sys.stderr)
        GLib = None

    # Камеру снимаем до GeoClue: первый же ответ helper'а должен быть полным,
    # без промежуточного «камеры нет».
    scan_camera()
    location = LocationWatcher()

    if GLib is None:
        # Без GLib остаётся камера: опрос в простом цикле.
        import time
        while running:
            time.sleep(CAMERA_POLL_MS / 1000.0)
            scan_camera()
        return

    loop = GLib.MainLoop()

    def poll_camera():
        if not running:
            loop.quit()
            return False
        scan_camera()
        return True

    def quit_loop():
        loop.quit()
        return False

    # Сигналы слушаем через GLib, а не через signal.signal: Python-обработчик
    # не выполнится, пока цикл GLib сидит в C-коде.
    try:
        from gi.repository import GLibUnix
        GLibUnix.signal_add(GLib.PRIORITY_HIGH, signal.SIGTERM, quit_loop)
        GLibUnix.signal_add(GLib.PRIORITY_HIGH, signal.SIGINT, quit_loop)
    except Exception:  # noqa: BLE001 — старый python-gobject
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGTERM, quit_loop)
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGINT, quit_loop)
    GLib.timeout_add(CAMERA_POLL_MS, poll_camera)

    loop.run()


if __name__ == "__main__":
    main()
