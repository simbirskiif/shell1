#!/usr/bin/env python3
"""fprintd-helper для экрана блокировки Quickshell: JSON-протокол stdin/stdout.

Зачем отдельный процесс: у Quickshell нет сервиса отпечатков, а `fprintd-verify`
перезапускается на каждую попытку и держит устройство только на время одного
сканирования. Здесь одно D-Bus-подключение к fprintd: устройство забирается
(Claim) один раз, а VerifyStart/VerifyStop переключаются командами, поэтому
повторное сканирование начинается без запуска нового процесса.

Протокол (по одной JSON-строке):
  stdin  — {"cmd":"verify"|"stop"|"quit"|"ping","user":"..."}
  stdout — {"ev":"..."}

События:
  ready       {"device":"...","enrolled":["right-index-finger"]}
  unavailable {"reason":"..."}              — устройства или отпечатков нет
  scanning    {}                            — VerifyStart принят, ждём палец
  finger      {"finger":"..."}              — fprintd выбрал палец
  status      {"status":"verify-match","done":true}
              statuses fprintd: verify-match, verify-no-match, verify-retry-scan,
              verify-swipe-too-short, verify-finger-not-centered,
              verify-remove-and-retry, verify-disconnected, verify-unknown-error
  error       {"message":"..."}             — ошибка D-Bus/разрешений
  stopped     {}                            — VerifyStop выполнен

Зависимости: python3 + dbus-python + python-gobject + glib2 (те же, что у
BlueZ-helper'а), плюс запущенный fprintd.
"""

import json
import os
import signal
import sys

import dbus
import dbus.exceptions
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib, GLibUnix

BUS_NAME = "net.reactivated.Fprint"
MANAGER_PATH = "/net/reactivated/Fprint/Manager"
MANAGER_IFACE = "net.reactivated.Fprint.Manager"
DEVICE_IFACE = "net.reactivated.Fprint.Device"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
FALLBACK_DEVICE = "/net/reactivated/Fprint/Device/0"


def emit(event, **fields):
    payload = {"ev": event}
    payload.update(fields)
    # stdout — только протокол; отладка идёт в stderr и не ломает разбор.
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def describe_error(error):
    name = ""
    try:
        name = error.get_dbus_name() or ""
    except AttributeError:
        pass
    message = str(error)
    return name + ": " + message if name else message


class Fprint:
    def __init__(self):
        DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        self.device_path = None
        self.device = None
        self.device_name = ""
        self.enrolled = []
        self.user = os.environ.get("USER") or ""
        self.claimed = False
        self.verifying = False
        self.loop = GLib.MainLoop()
        self.stdin_buffer = ""

    # ── обнаружение устройства ──────────────────────────────────────────

    def find_device(self):
        paths = []
        try:
            manager = dbus.Interface(
                self.bus.get_object(BUS_NAME, MANAGER_PATH), MANAGER_IFACE)
            paths = [str(path) for path in manager.GetDevices()]
        except dbus.exceptions.DBusException as error:
            print("[fprint-helper] Manager.GetDevices: " + describe_error(error),
                  file=sys.stderr, flush=True)

        if not paths and self.system_device_exists():
            paths = [FALLBACK_DEVICE]

        if not paths:
            emit("unavailable", reason="fingerprint sensor not found")
            return False

        self.device_path = paths[0]
        try:
            self.device = dbus.Interface(
                self.bus.get_object(BUS_NAME, self.device_path), DEVICE_IFACE)
            props = dbus.Interface(
                self.bus.get_object(BUS_NAME, self.device_path), PROPS_IFACE)
            self.device_name = str(props.Get(DEVICE_IFACE, "name"))
        except dbus.exceptions.DBusException as error:
            emit("unavailable", reason=describe_error(error))
            return False

        try:
            self.enrolled = [str(finger) for finger in
                             self.device.ListEnrolledFingers(self.user)]
        except dbus.exceptions.DBusException as error:
            # Права на список отпечатков не влияют на саму проверку: палец
            # можно приложить и без этого списка, поэтому не сдаёмся сразу.
            print("[fprint-helper] ListEnrolledFingers: " + describe_error(error),
                  file=sys.stderr, flush=True)
            self.enrolled = []

        if not self.enrolled:
            emit("unavailable", reason="no enrolled fingerprints")
            return False

        self.bus.add_signal_receiver(
            self.on_verify_status,
            signal_name="VerifyStatus",
            dbus_interface=DEVICE_IFACE,
            path=self.device_path)
        self.bus.add_signal_receiver(
            self.on_finger_selected,
            signal_name="VerifyFingerSelected",
            dbus_interface=DEVICE_IFACE,
            path=self.device_path)

        emit("ready", device=self.device_name, enrolled=self.enrolled)
        return True

    def system_device_exists(self):
        # fprintd старых версий не отдаёт Manager — проверяем типовой путь.
        try:
            return bool(self.bus.name_has_owner(BUS_NAME))
        except dbus.exceptions.DBusException:
            return False

    # ── команды ─────────────────────────────────────────────────────────

    def start_verify(self, user=None):
        if user:
            self.user = user
        if self.verifying or self.device is None:
            return
        try:
            if not self.claimed:
                self.device.Claim(self.user)
                self.claimed = True
            self.device.VerifyStart("any")
            self.verifying = True
            emit("scanning")
        except dbus.exceptions.DBusException as error:
            name = ""
            try:
                name = error.get_dbus_name() or ""
            except AttributeError:
                pass
            # Устройство занято другим клиентом (например, fprintd-verify):
            # это не повод умирать, но и повторять бесконечно нельзя —
            # интерфейс покажет ошибку и предложит пароль.
            emit("error", message=describe_error(error),
                 reason="busy" if "AlreadyInUse" in name else "failed")

    def stop_verify(self):
        if self.device is None:
            return
        try:
            if self.verifying:
                self.device.VerifyStop()
        except dbus.exceptions.DBusException as error:
            print("[fprint-helper] VerifyStop: " + describe_error(error),
                  file=sys.stderr, flush=True)
        self.verifying = False
        emit("stopped")

    def shutdown(self):
        self.stop_verify()
        if self.claimed and self.device is not None:
            try:
                self.device.Release()
            except dbus.exceptions.DBusException:
                pass
            self.claimed = False
        self.loop.quit()
        return False

    # ── сигналы fprintd ─────────────────────────────────────────────────

    def on_verify_status(self, result, done):
        result = str(result)
        done = bool(done)
        self.verifying = not done
        emit("status", status=result, done=done)
        if done:
            # Сессия проверки закончена; остановка освобождает устройство
            # для следующей попытки, Claim при этом сохраняется.
            try:
                self.device.VerifyStop()
            except dbus.exceptions.DBusException:
                pass

    def on_finger_selected(self, finger):
        emit("finger", finger=str(finger))

    # ── ввод команд ─────────────────────────────────────────────────────

    def handle_line(self, line):
        line = line.strip()
        if not line:
            return True
        try:
            command = json.loads(line)
        except ValueError:
            print("[fprint-helper] не JSON: " + line, file=sys.stderr, flush=True)
            return True

        name = command.get("cmd", "")
        if name == "verify":
            self.start_verify(command.get("user"))
        elif name == "stop":
            self.stop_verify()
        elif name == "ping":
            emit("pong")
        elif name == "quit":
            return self.shutdown()
        else:
            emit("error", message="unknown command: " + str(name), reason="protocol")
        return True

    def on_stdin_line(self, line):
        return self.handle_line(line)

    def run(self):
        if not self.find_device():
            return 0
        StdinReader(self, sys.stdin.fileno())
        try:
            self.loop.run()
        except KeyboardInterrupt:
            self.shutdown()
        return 0


class StdinReader:
    """Построчный разбор stdin без блокировки главного цикла.

    Как и в BlueZ-helper'е: GLib.IOChannel с NONBLOCK отдавал пустые строки,
    поэтому читаем через os.read по дескриптору.
    """

    def __init__(self, helper, fd):
        self.helper = helper
        self.buffer = b""
        os.set_blocking(fd, False)
        GLibUnix.fd_add_full(
            GLib.PRIORITY_DEFAULT, fd,
            GLib.IOCondition.IN | GLib.IOCondition.HUP,
            self.on_ready, None)

    def on_ready(self, fd, condition, _data):
        if condition & GLib.IOCondition.HUP:
            self.helper.shutdown()
            return False
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            return True
        except OSError as error:
            print("[fprint-helper] чтение stdin: " + str(error),
                  file=sys.stderr, flush=True)
            return False
        if not chunk:
            self.helper.shutdown()
            return False
        self.buffer += chunk
        while b"\n" in self.buffer:
            raw, self.buffer = self.buffer.split(b"\n", 1)
            text = raw.decode("utf-8", "replace").strip()
            if text and not self.helper.on_stdin_line(text):
                return False
        return True


def main():
    def on_signal(signum, frame):
        GLib.idle_add(helper.shutdown)

    helper = Fprint()
    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    return helper.run()


if __name__ == "__main__":
    sys.exit(main())
