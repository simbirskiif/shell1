#!/usr/bin/env python3
"""BlueZ-helper для Quickshell: JSON-протокол по stdin/stdout.

Зачем отдельный процесс: модуль Quickshell.Bluetooth не регистрирует
BlueZ-агента (в src/bluetooth/bluez.cpp нет ни AgentManager1, ни RegisterAgent),
а без агента устройства с подтверждением/авторизацией не спарить. Здесь агент
есть, поэтому спаривание идёт штатным путём BlueZ, а не через bluetoothctl.

Протокол (по одной JSON-строке):
  stdin  — {"id":"...","cmd":"..."} — команды
  stdout — {"ev":"..."}             — события

Команды:
  ping                                     — проверка живости
  snapshot                                 — перечитать состояние целиком
  power        {"value":true|false}        — Adapter1.Powered
  scan         {"start":true|false}        — StartDiscovery/StopDiscovery
  pair         {"address":"AA:.."}         — StopDiscovery → Pair → Trusted → Connect
  cancel_pair  {"address":"AA:.."}         — отменить текущее спаривание
  connect      {"address":"AA:.."}         — Connect с таймаутом
  disconnect   {"address":"AA:.."}         — Disconnect
  trust        {"address":"AA:..","value":true}
  remove       {"address":"AA:.."}         — Disconnect (если нужно) → RemoveDevice
  agent_reply  {"address":"AA:..","accept":true|false,"value":"..."}
  quit                                     — снять агента и выйти

События:
  ready / adapter / adapter_removed / device_added / device / device_removed
  agent_registered / helper / error
  agent  — запрос BlueZ-агента, ждём agent_reply (таймаут 30 с)
  phase  {"address":..,"phase":"pairing|trusting|connecting"} — ход pair-цепочки
  result {"id":..,"ok":..,"error":..,"address":..}

Зависимости: python3 + dbus-python + python-gobject + glib2 — системные пакеты
Arch (python-dbus, python-gobject, glib2), устанавливать нечего. dbus-fast в
системе отсутствует, pip в окружении недоступен, поэтому используется
dbus-python: тот же D-Bus, те же возможности (вызовы, сигналы, экспорт
объектов, GLib-цикл).

Изменения состояния приходят ТОЛЬКО сигналами ObjectManager и
PropertiesChanged. Опроса по таймеру нет.
"""

import json
import os
import signal
import sys

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib, GLibUnix

BLUEZ = "org.bluez"
OM_IFACE = "org.freedesktop.DBus.ObjectManager"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
ADAPTER_IFACE = "org.bluez.Adapter1"
DEVICE_IFACE = "org.bluez.Device1"
BATTERY_IFACE = "org.bluez.Battery1"
AGENT_IFACE = "org.bluez.Agent1"
AGENT_MANAGER_IFACE = "org.bluez.AgentManager1"
AGENT_PATH = "/org/qs/agent"
AGENT_CAPABILITY = "KeyboardDisplay"
AGENT_TIMEOUT_SECONDS = 30

PAIR_TIMEOUT_SECONDS = 45
CONNECT_TIMEOUT_SECONDS = 30
SIMPLE_TIMEOUT_SECONDS = 15
DISCOVERY_STOP_TIMEOUT_SECONDS = 3

# Pairing в BlueZ НЕ существует как свойство: «идёт ли спаривание» выводится
# по ходу операции и отдаётся событием phase.
DEVICE_PROPS = [
    "Address", "Alias", "Name", "Icon", "Class",
    "Paired", "Bonded", "Connected", "Trusted", "Blocked",
    "ServicesResolved", "Adapter", "UUIDs", "RSSI",
]
ADAPTER_PROPS = [
    "Address", "Name", "Alias", "Powered", "Discovering", "Discoverable",
    "DiscoverableTimeout", "Pairable", "PairableTimeout", "PowerState",
]

# "auto" — и BR/EDR, и LE; дубликаты не нужны.
SCAN_FILTER = {"Transport": "auto", "DuplicateData": False}

ERROR_TEXTS = {
    "org.bluez.Error.AuthenticationFailed": (
        "Не удалось аутентифицироваться",
        "Устройство отклонило аутентификацию. Уберите его из списка и спарьте заново."),
    "org.bluez.Error.AuthenticationRejected": (
        "Аутентификация отклонена",
        "Устройство отклонило запрос. Проверьте, принято ли подтверждение на самом устройстве."),
    "org.bluez.Error.AuthenticationCanceled": (
        "Аутентификация отменена",
        "Устройство отменило сопряжение. Обычно это значит, что оно подключено к другому "
        "устройству (телефону/планшету) или уже вышло из режима сопряжения. Отключите его "
        "от другого устройства и переведите в режим сопряжения."),
    "org.bluez.Error.AuthenticationTimeout": (
        "Таймаут аутентификации",
        "Устройство не подтвердило сопряжение вовремя. Попробуйте ещё раз."),
    "org.bluez.Error.ConnectionAttemptFailed": (
        "Не удалось подключиться",
        "Устройство не отвечает. Проверьте, что оно включено и находится рядом."),
    "org.bluez.Error.AlreadyExists": (
        "Уже существует",
        "Устройство уже спарено или уже подключено."),
    "org.bluez.Error.InProgress": (
        "Операция уже идёт",
        "Дождитесь завершения текущей операции."),
    "org.bluez.Error.NotReady": (
        "Bluetooth не готов",
        "Адаптер выключен или ещё не поднялся. Включите Bluetooth и повторите."),
    "org.bluez.Error.NotAvailable": (
        "Устройство недоступно",
        "BlueZ не видит устройство: оно вышло из зоны или уже удалено."),
    "org.bluez.Error.NotPermitted": (
        "Операция не разрешена",
        "BlueZ запретил действие для этого устройства."),
    "org.bluez.Error.InvalidArguments": (
        "Некорректные параметры",
        "BlueZ не принял параметры операции."),
    "org.bluez.Error.NotSupported": (
        "Не поддерживается",
        "Устройство или адаптер не поддерживает эту операцию."),
    "org.bluez.Error.Canceled": ("Операция отменена", ""),
    "org.bluez.Error.Rejected": (
        "Запрос отклонён",
        "Сопряжение отклонено. Повторите и подтвердите его на устройстве."),
    "org.bluez.Error.Failed": (
        "Операция не удалась",
        "BlueZ отклонил операцию. Подробности — в журнале bluetoothd."),
}


def log(message):
    """Диагностика в stderr: stdout занят протоколом."""
    sys.stderr.write("[helper] %s\n" % message)
    sys.stderr.flush()


def emit(event):
    """Отдать событие в QML одной строкой JSON."""
    sys.stdout.write(json.dumps(event, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def to_plain(value):
    """Приводим типы dbus к обычным Python, чтобы json.dumps не падал."""
    if isinstance(value, dbus.Boolean):
        return bool(value)
    if isinstance(value, (dbus.Byte, dbus.Int16, dbus.Int32, dbus.Int64,
                          dbus.UInt16, dbus.UInt32, dbus.UInt64)):
        return int(value)
    if isinstance(value, dbus.Double):
        return float(value)
    if isinstance(value, (dbus.ObjectPath, dbus.String)):
        return str(value)
    if isinstance(value, (dbus.Array, list, tuple)):
        return [to_plain(v) for v in value]
    if isinstance(value, (dbus.Dictionary, dict)):
        return {str(k): to_plain(v) for k, v in value.items()}
    return value


def pick(props, names):
    """Оставляем только нужные свойства, приведённые к простым типам."""
    out = {}
    for name in names:
        if name in props:
            out[name] = to_plain(props[name])
    return out


def error_text(exc):
    """Имя ошибки BlueZ плюс её текст: UI разбирает по имени."""
    try:
        name = exc.get_dbus_name() or ""
    except Exception:                                   # noqa: BLE001
        name = ""
    try:
        message = exc.get_dbus_message()
    except Exception:                                   # noqa: BLE001
        message = str(exc)
    if name in ERROR_TEXTS:
        short, _hint = ERROR_TEXTS[name]
        return "%s: %s" % (name, short) if not message else "%s (%s)" % (name, message)
    return message or name or str(exc)


def error_hint(text):
    """Подсказка «что сделать» по тексту ошибки."""
    text = str(text)
    for name, (_short, hint) in ERROR_TEXTS.items():
        if name in text and hint:
            return hint
    return ""


def format_error(exc):
    """Текст ошибки для result: таймаут или ошибка BlueZ."""
    if exc is None:
        return ""
    if isinstance(exc, TimeoutError):
        return str(exc)
    if isinstance(exc, dbus.exceptions.DBusException):
        return error_text(exc)
    return str(exc)


class Agent(dbus.service.Object):
    """BlueZ-агент на /org/qs/agent.

    Каждый запрос уходит в QML событием agent и ждёт agent_reply с таймаутом
    30 с. По таймауту или Cancel отдаём BlueZ Rejected/Canceled, иначе
    сопряжение повисло бы.
    """

    def __init__(self, helper, path=AGENT_PATH):
        self.helper = helper
        self.pending = None
        super().__init__(dbus.SystemBus(), path)

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="s")
    def RequestPinCode(self, device, transport):
        answer = self.ask("RequestPinCode", device, {"kind": "pin"})
        return dbus.String(str(answer) if answer is not None else "")

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        answer = self.ask("RequestPasskey", device, {"kind": "passkey"})
        try:
            return dbus.UInt32(int(answer))
        except (TypeError, ValueError):
            return dbus.UInt32(0)

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        emit({"ev": "agent", "request": "DisplayPasskey",
              "address": self.address_of(device),
              "passkey": int(passkey), "entered": int(entered)})

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        emit({"ev": "agent", "request": "DisplayPinCode",
              "address": self.address_of(device), "pincode": str(pincode)})

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        self.ask("RequestConfirmation", device, {"passkey": int(passkey)})

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        # Авторизация подключения — рутинный шаг: у уже спаренного устройства
        # спрашивать пользователя не о чем (так же ведут себя bluetoothctl и
        # blueman). Отвечаем сразу, только помечаем событием для лога UI.
        emit({"ev": "agent_auto", "request": "RequestAuthorization",
              "address": self.address_of(device)})

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        # Авторизация сервиса (профиля) — тоже рутинный шаг: BlueZ вызывает её
        # на каждый профиль, и диалог на каждый превращался в несколько
        # подряд «разрешить подключение?». Принимаем молча.
        emit({"ev": "agent_auto", "request": "AuthorizeService",
              "address": self.address_of(device), "uuid": str(uuid)})

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        emit({"ev": "agent", "request": "Cancel", "address": None})
        if self.pending is not None:
            self.pending["cancelled"] = True
            self.pending["loop"].quit()

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        log("агент освобождён BlueZ")
        self.pending = None

    def address_of(self, device):
        return self.helper.address_of_path(str(device))

    def ask(self, request, device, extra):
        """Спросить QML и подождать agent_reply (или таймаут/Cancel)."""
        event = {"ev": "agent", "request": request,
                 "address": self.address_of(device)}
        event.update(extra)
        emit(event)

        loop = GLib.MainLoop()
        self.pending = {"loop": loop, "cancelled": False, "answer": None}

        def on_timeout():
            if self.pending is not None and self.pending["loop"] is loop:
                log("%s: таймаут ответа агента (%d с)"
                    % (request, AGENT_TIMEOUT_SECONDS))
                loop.quit()
            return False

        timeout_id = GLib.timeout_add_seconds(AGENT_TIMEOUT_SECONDS, on_timeout)
        loop.run()
        GLib.source_remove(timeout_id)

        answer = self.pending["answer"] if self.pending else None
        cancelled = self.pending["cancelled"] if self.pending else False
        self.pending = None

        # answer=False — это отказ пользователя (кнопка «Отмена»), и его
        # обязательно надо превратить в Rejected: иначе метод просто
        # возвращался бы, и BlueZ счёл бы сопряжение подтверждённым.
        if cancelled and answer is None:
            raise dbus.exceptions.DBusException(
                "Cancelled", name="org.bluez.Error.Canceled")
        if answer is None or answer is False:
            raise dbus.exceptions.DBusException(
                "Rejected", name="org.bluez.Error.Rejected")
        return answer

    def reply(self, answer):
        """Ответ из QML (команда agent_reply)."""
        if self.pending is None:
            return
        self.pending["answer"] = answer
        self.pending["loop"].quit()


class BluezHelper:
    """Снимок состояния BlueZ и операции. Изменения — только по сигналам."""

    def __init__(self):
        self.bus = dbus.SystemBus()
        self.om = dbus.Interface(self.bus.get_object(BLUEZ, "/"), OM_IFACE)
        self.adapters = {}
        self.devices = {}
        self.agent = None
        # Одна операция на адрес: повторный вызов получает Busy.
        self.operations = set()
        # Таймаут видимости: 0 в BlueZ значит «бессрочно».
        self.discoverable_timeout = 180
        # Ожидание Discovering=false перед pair/connect: ждём событие, а не
        # опрашиваем состояние.
        self.discovery_wait = None
        self.subscribe()
        self.register_agent()
        self.snapshot()

    # ───────────── подписки ─────────────

    def subscribe(self):
        self.bus.add_signal_receiver(
            self.on_interfaces_added, dbus_interface=OM_IFACE,
            signal_name="InterfacesAdded", bus_name=BLUEZ)
        self.bus.add_signal_receiver(
            self.on_interfaces_removed, dbus_interface=OM_IFACE,
            signal_name="InterfacesRemoved", bus_name=BLUEZ)
        # Путь объекта приходит в kwargs (path_keyword).
        self.bus.add_signal_receiver(
            self.on_properties_changed, dbus_interface=PROPS_IFACE,
            signal_name="PropertiesChanged", bus_name=BLUEZ,
            path_keyword="path")
        self.bus.add_signal_receiver(
            self.on_name_owner_changed, dbus_interface="org.freedesktop.DBus",
            signal_name="NameOwnerChanged", arg0=BLUEZ)

    def on_name_owner_changed(self, name, old_owner, new_owner):
        if str(new_owner) == "":
            log("bluetoothd ушёл из шины")
            self.adapters.clear()
            self.devices.clear()
            self.agent = None
            self.operations.clear()
            emit({"ev": "helper", "online": False})
            return
        log("bluetoothd появился в шине, перечитываю состояние")
        self.register_agent()
        self.snapshot()
        emit({"ev": "helper", "online": True})

    # ───────────── снимок ─────────────

    def snapshot(self):
        try:
            objects = self.om.GetManagedObjects()
        except dbus.exceptions.DBusException as exc:
            log("GetManagedObjects не удался: %s" % exc)
            emit({"ev": "error", "error": error_text(exc)})
            return
        self.adapters.clear()
        self.devices.clear()
        for raw_path, ifaces in objects.items():
            path = str(raw_path)
            if ADAPTER_IFACE in ifaces:
                self.adapters[path] = {
                    "ifaces": set(str(i) for i in ifaces.keys()),
                    "props": pick(ifaces[ADAPTER_IFACE], ADAPTER_PROPS),
                }
            if DEVICE_IFACE in ifaces:
                props = pick(ifaces[DEVICE_IFACE], DEVICE_PROPS)
                if BATTERY_IFACE in ifaces:
                    props["Battery"] = to_plain(
                        ifaces[BATTERY_IFACE].get("Percentage"))
                self.devices[path] = {
                    "ifaces": set(str(i) for i in ifaces.keys()),
                    "props": props,
                }
        adapter = self.primary_adapter_path()
        emit({
            "ev": "ready",
            "adapter": os.path.basename(adapter) if adapter else None,
            "adapters": [self.adapter_json(p) for p in sorted(self.adapters)],
            "devices": [self.device_json(p) for p in sorted(self.devices)],
        })

    def adapter_json(self, path):
        entry = self.adapters.get(path)
        if entry is None:
            return None
        data = {"path": path, "id": os.path.basename(path)}
        data.update(entry["props"])
        return data

    def device_json(self, path):
        entry = self.devices.get(path)
        if entry is None:
            return None
        data = {"path": path}
        data.update(entry["props"])
        return data

    # ───────────── сигналы BlueZ ─────────────

    def on_interfaces_added(self, path, interfaces):
        path = str(path)
        interfaces = to_plain(interfaces)
        if ADAPTER_IFACE in interfaces:
            self.adapters[path] = {
                "ifaces": set(interfaces.keys()),
                "props": pick(interfaces[ADAPTER_IFACE], ADAPTER_PROPS),
            }
            emit({"ev": "adapter", "path": path,
                  "props": self.adapters[path]["props"]})
        if DEVICE_IFACE in interfaces:
            props = pick(interfaces[DEVICE_IFACE], DEVICE_PROPS)
            if BATTERY_IFACE in interfaces:
                props["Battery"] = to_plain(
                    interfaces[BATTERY_IFACE].get("Percentage"))
            self.devices[path] = {
                "ifaces": set(interfaces.keys()), "props": props}
            emit({"ev": "device_added", "path": path, "props": props})
        elif BATTERY_IFACE in interfaces and path in self.devices:
            self.devices[path]["ifaces"].add(BATTERY_IFACE)
            self.devices[path]["props"]["Battery"] = to_plain(
                interfaces[BATTERY_IFACE].get("Percentage"))
            emit({"ev": "device", "path": path,
                  "props": self.devices[path]["props"]})

    def on_interfaces_removed(self, path, interfaces):
        path = str(path)
        interfaces = [str(i) for i in interfaces]
        if ADAPTER_IFACE in interfaces:
            self.adapters.pop(path, None)
            emit({"ev": "adapter_removed", "path": path})
        if DEVICE_IFACE in interfaces:
            self.devices.pop(path, None)
            emit({"ev": "device_removed", "path": path})
        elif BATTERY_IFACE in interfaces and path in self.devices:
            self.devices[path]["ifaces"].discard(BATTERY_IFACE)
            self.devices[path]["props"].pop("Battery", None)
            emit({"ev": "device", "path": path,
                  "props": self.devices[path]["props"]})

    def on_properties_changed(self, interface, changed, invalidated, path=None):
        interface = str(interface)
        changed = to_plain(changed)
        if path is None:
            return
        path = str(path)
        if interface == DEVICE_IFACE and path in self.devices:
            self.devices[path]["props"].update(pick(changed, DEVICE_PROPS))
            emit({"ev": "device", "path": path,
                  "props": self.devices[path]["props"]})
        elif interface == BATTERY_IFACE and path in self.devices:
            if "Percentage" in changed:
                self.devices[path]["props"]["Battery"] = to_plain(
                    changed["Percentage"])
                emit({"ev": "device", "path": path,
                      "props": self.devices[path]["props"]})
        elif interface == ADAPTER_IFACE and path in self.adapters:
            self.adapters[path]["props"].update(pick(changed, ADAPTER_PROPS))
            emit({"ev": "adapter", "path": path,
                  "props": self.adapters[path]["props"]})
            # Скан снялся — будим ожидание в stop_discovery_for_operation().
            wait = self.discovery_wait
            if (wait is not None and wait["path"] == path
                    and self.adapters[path]["props"].get("Discovering") is False):
                wait["loop"].quit()

    # ───────────── утилиты ─────────────

    def primary_adapter_path(self):
        if not self.adapters:
            return None
        return sorted(self.adapters.keys())[0]

    def address_of_path(self, path):
        entry = self.devices.get(path)
        if entry is not None:
            return str(entry["props"].get("Address", ""))
        if "/dev_" in path:
            return path.rsplit("dev_", 1)[-1].replace("_", ":")
        return ""

    def find_device_path(self, address):
        if not address:
            return None
        wanted = str(address).upper()
        for path, entry in self.devices.items():
            if str(entry["props"].get("Address", "")).upper() == wanted:
                return path
        return None

    def device_iface(self, path):
        return dbus.Interface(self.bus.get_object(BLUEZ, path), DEVICE_IFACE)

    def adapter_iface(self, path):
        return dbus.Interface(self.bus.get_object(BLUEZ, path), ADAPTER_IFACE)

    def set_property(self, path, interface, name, value):
        """Запись свойства: только через org.freedesktop.DBus.Properties."""
        dbus.Interface(self.bus.get_object(BLUEZ, path), PROPS_IFACE).Set(
            interface, name, value)

    def emit_result(self, req_id, ok, address=None, error=None):
        event = {"ev": "result", "id": req_id, "ok": ok}
        if address is not None:
            event["address"] = address
        if error is not None:
            event["error"] = error
        emit(event)

    def phase(self, address, phase):
        emit({"ev": "phase", "address": address, "phase": phase})

    # ───────────── операции ─────────────

    def begin_operation(self, address):
        if not address or address in self.operations:
            return False
        self.operations.add(address)
        return True

    def end_operation(self, address):
        self.operations.discard(address)

    def call_async(self, func, timeout_seconds, on_done, *args):
        """Асинхронно вызвать метод BlueZ и вернуть управление главному циклу.

        Так обязательно: синхронный вызов (или ожидание потока через
        done.wait()) блокирует главный цикл GLib, и тогда входящий вызов BlueZ
        к агенту — RequestPinCode/RequestConfirmation — не обрабатывается, пока
        операция не завершится. Из-за этого окно ввода PIN всплывало только
        после таймаута устройства.

        on_done получает None при успехе или исключение.
        """
        state = {"done": False}

        def finish(error):
            if state["done"]:
                return
            state["done"] = True
            if timer_id[0] is not None:
                GLib.source_remove(timer_id[0])
                timer_id[0] = None
            on_done(error)

        def on_timeout():
            finish(TimeoutError("таймаут операции (%d с)" % timeout_seconds))
            return False

        timer_id = [GLib.timeout_add_seconds(timeout_seconds, on_timeout)]

        def on_reply(*_args):
            finish(None)

        def on_error(exc):
            finish(exc)

        try:
            func(*args, reply_handler=on_reply, error_handler=on_error)
        except Exception as exc:                        # noqa: BLE001
            finish(exc)

    def stop_discovery_for_operation(self):
        """Остановить скан перед pair/connect и дождаться Discovering=false.

        Пока идёт inquiry, радио занято, и BlueZ нередко срывает подключение.
        Ждём СОБЫТИЕ PropertiesChanged (в on_properties_changed), а таймер на
        3 с оставлен только страховкой — опроса состояния нет.
        """
        path = self.primary_adapter_path()
        if path is None:
            return
        entry = self.adapters.get(path)
        if not entry or not entry["props"].get("Discovering"):
            return
        try:
            self.adapter_iface(path).StopDiscovery()
        except dbus.exceptions.DBusException as exc:
            log("StopDiscovery: %s" % error_text(exc))

        loop = GLib.MainLoop()
        self.discovery_wait = {"path": path, "loop": loop}

        def on_timeout():
            wait = self.discovery_wait
            if wait is not None and wait["loop"] is loop:
                log("Discovering не снялось за %d с — продолжаю"
                    % DISCOVERY_STOP_TIMEOUT_SECONDS)
                loop.quit()
            return False

        timeout_id = GLib.timeout_add_seconds(DISCOVERY_STOP_TIMEOUT_SECONDS,
                                              on_timeout)
        loop.run()
        GLib.source_remove(timeout_id)
        self.discovery_wait = None

    def cmd_power(self, req_id, value):
        path = self.primary_adapter_path()
        if path is None:
            self.emit_result(req_id, False, error="нет адаптера")
            return
        try:
            self.set_property(path, ADAPTER_IFACE, "Powered",
                              dbus.Boolean(bool(value)))
            self.emit_result(req_id, True)
        except dbus.exceptions.DBusException as exc:
            self.emit_result(req_id, False, error=error_text(exc))

    def cmd_scan(self, req_id, start):
        path = self.primary_adapter_path()
        if path is None:
            self.emit_result(req_id, False, error="нет адаптера")
            return
        iface = self.adapter_iface(path)
        try:
            if start:
                iface.SetDiscoveryFilter(
                    dbus.Dictionary(SCAN_FILTER, signature="sv"))
                iface.StartDiscovery()
            else:
                iface.StopDiscovery()
            self.emit_result(req_id, True)
        except dbus.exceptions.DBusException as exc:
            text = error_text(exc)
            # «уже идёт» и «не идёт» — не ошибки для UI.
            if "InProgress" in text or "No discovery started" in text:
                self.emit_result(req_id, True)
                return
            self.emit_result(req_id, False, error=text)

    def cmd_discoverable(self, req_id, value):
        """Видимость адаптера. Таймаут ставим до включения: BlueZ применяет
        его в момент записи Discoverable=true."""
        path = self.primary_adapter_path()
        if path is None:
            self.emit_result(req_id, False, error="нет адаптера")
            return
        try:
            if value:
                self.set_property(path, ADAPTER_IFACE, "DiscoverableTimeout",
                                  dbus.UInt32(self.discoverable_timeout))
                self.set_property(path, ADAPTER_IFACE, "Discoverable",
                                  dbus.Boolean(True))
            else:
                self.set_property(path, ADAPTER_IFACE, "Discoverable",
                                  dbus.Boolean(False))
            self.emit_result(req_id, True)
        except dbus.exceptions.DBusException as exc:
            self.emit_result(req_id, False, error=error_text(exc))

    def cmd_trust(self, req_id, address, value=True):
        path = self.find_device_path(address)
        if path is None:
            self.emit_result(req_id, False, address=address,
                             error="устройство не найдено")
            return
        try:
            self.set_property(path, DEVICE_IFACE, "Trusted",
                              dbus.Boolean(bool(value)))
            self.emit_result(req_id, True, address=address)
        except dbus.exceptions.DBusException as exc:
            self.emit_result(req_id, False, address=address, error=error_text(exc))

    def cmd_connect(self, req_id, address):
        path = self.find_device_path(address)
        if path is None:
            self.emit_result(req_id, False, address=address,
                             error="устройство не найдено")
            return
        if not self.begin_operation(address):
            self.emit_result(req_id, False, address=address, error="Busy")
            return
        self.stop_discovery_for_operation()
        self.phase(address, "connecting")

        def done(error):
            if error is None:
                self.emit_result(req_id, True, address=address)
            else:
                self.emit_result(req_id, False, address=address,
                                 error=format_error(error))
            self.end_operation(address)

        self.call_async(self.device_iface(path).Connect,
                        CONNECT_TIMEOUT_SECONDS, done)

    def cmd_disconnect(self, req_id, address):
        path = self.find_device_path(address)
        if path is None:
            self.emit_result(req_id, False, address=address,
                             error="устройство не найдено")
            return
        if not self.begin_operation(address):
            self.emit_result(req_id, False, address=address, error="Busy")
            return

        def done(error):
            if error is None:
                self.emit_result(req_id, True, address=address)
            else:
                self.emit_result(req_id, False, address=address,
                                 error=format_error(error))
            self.end_operation(address)

        self.call_async(self.device_iface(path).Disconnect,
                        SIMPLE_TIMEOUT_SECONDS, done)

    def cmd_remove(self, req_id, address):
        """Disconnect (если подключено) → Adapter1.RemoveDevice.

        Никакого bluetoothctl: ошибка BlueZ отдаётся как есть.
        """
        path = self.find_device_path(address)
        if path is None:
            self.emit_result(req_id, False, address=address,
                             error="устройство не найдено")
            return
        if not self.begin_operation(address):
            self.emit_result(req_id, False, address=address, error="Busy")
            return

        def after_remove(error):
            if error is None:
                self.emit_result(req_id, True, address=address)
            else:
                self.emit_result(req_id, False, address=address,
                                 error=format_error(error))
            self.end_operation(address)

        def do_remove(_error=None):
            adapter_path = self.primary_adapter_path()
            if adapter_path is None:
                self.emit_result(req_id, False, address=address,
                                 error="нет адаптера")
                self.end_operation(address)
                return
            self.call_async(self.adapter_iface(adapter_path).RemoveDevice,
                            SIMPLE_TIMEOUT_SECONDS, after_remove,
                            dbus.ObjectPath(path))

        props = self.devices.get(path, {}).get("props", {})
        if props.get("Connected"):
            # Сначала отключаем; если не вышло — всё равно пробуем удалить.
            self.call_async(self.device_iface(path).Disconnect,
                            SIMPLE_TIMEOUT_SECONDS, do_remove)
        else:
            do_remove()

    def cmd_pair(self, req_id, address):
        """Pair-цепочка: StopDiscovery → Pair → Trusted → Connect.

        Всё асинхронно: пока идёт Pair(), главный цикл свободен и агент может
        принять RequestPinCode/RequestConfirmation СРАЗУ. Синхронное ожидание
        блокировало цикл, и окно ввода PIN всплывало только после таймаута
        устройства.
        """
        path = self.find_device_path(address)
        if path is None:
            self.emit_result(req_id, False, address=address,
                             error="устройство не найдено")
            return
        if not self.begin_operation(address):
            self.emit_result(req_id, False, address=address, error="Busy")
            return

        iface = self.device_iface(path)

        def finish(error):
            if error is None:
                self.emit_result(req_id, True, address=address)
            else:
                self.emit_result(req_id, False, address=address,
                                 error=format_error(error))
            self.end_operation(address)

        def after_connect(error):
            finish(error)

        def after_pair(error):
            if error is not None:
                finish(error)
                return
            self.phase(address, "trusting")
            try:
                self.set_property(path, DEVICE_IFACE, "Trusted", dbus.Boolean(True))
            except dbus.exceptions.DBusException as exc:
                finish(exc)
                return
            self.phase(address, "connecting")
            self.call_async(iface.Connect, CONNECT_TIMEOUT_SECONDS, after_connect)

        self.stop_discovery_for_operation()
        self.phase(address, "pairing")
        self.call_async(iface.Pair, PAIR_TIMEOUT_SECONDS, after_pair)

    def cmd_cancel_pair(self, req_id, address):
        path = self.find_device_path(address)
        if path is None:
            self.emit_result(req_id, False, address=address,
                             error="устройство не найдено")
            return
        try:
            self.device_iface(path).CancelPairing()
            self.emit_result(req_id, True, address=address)
        except dbus.exceptions.DBusException as exc:
            self.emit_result(req_id, False, address=address, error=error_text(exc))

    def cmd_agent_info(self, req_id):
        """Что реально экспортировано агентом: интерфейс, методы, сигнатуры.

        Round-trip из userspace проверить нельзя (политика D-Bus не пускает
        вызовы к чужому уникальному имени) — зовёт агента только сам BlueZ.
        А состав экспортированных методов читаем из атрибутов, которые
        проставляет декоратор dbus.service.method.
        """
        if self.agent is None:
            self.emit_result(req_id, False, error="агент не зарегистрирован")
            return
        methods = []
        interfaces = set()
        for name in dir(type(self.agent)):
            fn = getattr(type(self.agent), name, None)
            if not callable(fn) or not getattr(fn, "_dbus_is_method", False):
                continue
            interface = str(getattr(fn, "_dbus_interface", AGENT_IFACE))
            interfaces.add(interface)
            methods.append({
                "name": name,
                "interface": interface,
                "in_signature": str(getattr(fn, "_dbus_in_signature", "")),
                "out_signature": str(getattr(fn, "_dbus_out_signature", "")),
            })
        try:
            # locations — свойство dbus-python; может быть итератором.
            raw = self.agent.locations.get(dbus.SystemBus(), [])
            locations = [str(p) for p in list(raw)]
        except Exception as exc:                        # noqa: BLE001
            locations = ["<ошибка: %s>" % exc]
        emit({"ev": "agent_info", "info": {
            "registered": True, "path": AGENT_PATH,
            "capability": AGENT_CAPABILITY,
            "unique_name": str(self.bus.get_unique_name()),
            "interfaces": sorted(interfaces),
            "methods": methods, "locations": locations,
        }})
        self.emit_result(req_id, True)

    def cmd_agent_reply(self, req_id, address, accept, value):
        if self.agent is None:
            self.emit_result(req_id, False, address=address,
                             error="агент не зарегистрирован")
            return
        answer = value if (accept and value not in (None, "")) else accept
        self.agent.reply(answer)
        self.emit_result(req_id, True, address=address)

    # ───────────── агент ─────────────

    def register_agent(self):
        if self.agent is not None:
            return
        self.agent = Agent(self)
        manager = dbus.Interface(
            self.bus.get_object(BLUEZ, "/org/bluez"), AGENT_MANAGER_IFACE)
        try:
            manager.RegisterAgent(dbus.ObjectPath(AGENT_PATH), AGENT_CAPABILITY)
            manager.RequestDefaultAgent(dbus.ObjectPath(AGENT_PATH))
            log("агент зарегистрирован (%s), уникальное имя %s"
                % (AGENT_CAPABILITY, self.bus.get_unique_name()))
            # Уникальное имя нужно тестам и диагностике: BlueZ вызывает агента
            # по имени отправителя RegisterAgent, а не по org.bluez.
            emit({"ev": "agent_registered", "capability": AGENT_CAPABILITY,
                  "unique_name": str(self.bus.get_unique_name())})
        except dbus.exceptions.DBusException as exc:
            log("не удалось зарегистрировать агента: %s" % exc)
            emit({"ev": "error", "error": "agent: %s" % error_text(exc)})

    def unregister_agent(self):
        if self.agent is None:
            return
        try:
            dbus.Interface(
                self.bus.get_object(BLUEZ, "/org/bluez"),
                AGENT_MANAGER_IFACE).UnregisterAgent(dbus.ObjectPath(AGENT_PATH))
        except dbus.exceptions.DBusException:
            pass
        self.agent = None


def handle_command(helper, raw):
    """Разбор одной команды из stdin."""
    try:
        cmd = json.loads(raw)
    except ValueError as exc:
        log("не разобрал команду: %s (%s)" % (raw, exc))
        return
    name = cmd.get("cmd")
    req_id = cmd.get("id")
    address = cmd.get("address", "")

    if name == "ping":
        helper.emit_result(req_id, True)
    elif name == "snapshot":
        helper.snapshot()
        helper.emit_result(req_id, True)
    elif name == "power":
        helper.cmd_power(req_id, cmd.get("value", True))
    elif name == "scan":
        helper.cmd_scan(req_id, cmd.get("start", True))
    elif name == "discoverable":
        helper.cmd_discoverable(req_id, cmd.get("value", True))
    elif name == "trust":
        helper.cmd_trust(req_id, address, cmd.get("value", True))
    elif name == "connect":
        helper.cmd_connect(req_id, address)
    elif name == "disconnect":
        helper.cmd_disconnect(req_id, address)
    elif name == "remove":
        helper.cmd_remove(req_id, address)
    elif name == "pair":
        helper.cmd_pair(req_id, address)
    elif name == "cancel_pair":
        helper.cmd_cancel_pair(req_id, address)
    elif name == "agent_info":
        helper.cmd_agent_info(req_id)
    elif name == "agent_reply":
        helper.cmd_agent_reply(req_id, address, bool(cmd.get("accept", True)),
                               cmd.get("value"))
    elif name == "quit":
        helper.emit_result(req_id, True)
        helper.unregister_agent()
        GLib.MainLoop().quit()
    else:
        helper.emit_result(req_id, False, error="неизвестная команда: %s" % name)


class StdinReader:
    """Построчный разбор stdin без блокировки главного цикла.

    GLib.IOChannel с NONBLOCK отдавал пустые строки (команды не доходили),
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
            log("stdin закрыт — завершаемся")
            self.helper.unregister_agent()
            GLib.MainLoop().quit()
            return False
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            return True
        except OSError as exc:
            log("чтение stdin: %s" % exc)
            return False
        if not chunk:
            return True
        self.buffer += chunk
        while b"\n" in self.buffer:
            raw, self.buffer = self.buffer.split(b"\n", 1)
            text = raw.decode("utf-8", "replace").strip()
            if text:
                handle_command(self.helper, text)
        return True


def main():
    DBusGMainLoop(set_as_default=True)
    helper = BluezHelper()
    StdinReader(helper, sys.stdin.fileno())

    def on_signal(signum, frame):
        helper.unregister_agent()
        GLib.MainLoop().quit()

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    log("helper запущен, жду команды в stdin")
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
