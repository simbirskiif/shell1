#!/usr/bin/env python3
"""Проверка агента helper'а без PIN-устройства.

Симулируем BlueZ: вызываем методы org.bluez.Agent1 на /org/qs/agent и смотрим,
что helper отдаёт событие agent в stdout и ждёт agent_reply, а метод
возвращается после ответа. Запускается вручную/из тестов.
"""

import json
import os
import subprocess
import sys
import threading
import time

import dbus

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "qs-bluetooth-helper.py")
AGENT_PATH = "/org/qs/agent"
AGENT_IFACE = "org.bluez.Agent1"
# Путь устройства: helper выведет адрес из имени объекта.
FAKE_DEVICE = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"

results = []


def check(label, condition, detail=""):
    results.append((label, bool(condition), detail))
    print(("PASS  " if condition else "FAIL  ") + label
          + (("  [" + str(detail) + "]") if detail != "" else ""))


class Helper:
    def __init__(self):
        self.proc = subprocess.Popen(
            [sys.executable, HELPER], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        self.events = []

    def read_until(self, predicate, seconds):
        import select
        deadline = time.time() + seconds
        while time.time() < deadline:
            if select.select([self.proc.stdout], [], [], 0.2)[0]:
                line = self.proc.stdout.readline()
                if not line:
                    return None
                line = line.strip()
                if not line:
                    continue
                event = json.loads(line)
                self.events.append(event)
                print("   событие:", event)
                if predicate(event):
                    return event
        return None

    def send(self, **cmd):
        cmd.setdefault("id", str(len(self.events) + 100))
        self.proc.stdin.write(json.dumps(cmd) + "\n")
        self.proc.stdin.flush()
        return cmd["id"]

    def close(self):
        try:
            self.send(cmd="quit")
            time.sleep(0.3)
        except Exception:
            pass
        self.proc.terminate()
        try:
            self.proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.proc.kill()


def main():
    helper = Helper()
    ready = helper.read_until(lambda e: e.get("ev") == "ready", 10)
    check("helper прислал ready", ready is not None)
    if ready is None:
        helper.close()
        return 1

    # Агент экспортирован на соединении helper'а, поэтому обращаемся по его
    # уникальному имени — так же, как это делает BlueZ (по имени отправителя
    # RegisterAgent), а не по org.bluez.
    registered = [e for e in helper.events if e.get("ev") == "agent_registered"]
    check("агент зарегистрирован", len(registered) > 0)
    unique_name = registered[-1].get("unique_name") if registered else None
    check("helper сообщил уникальное имя", bool(unique_name), unique_name)
    if not unique_name:
        helper.close()
        return 1

    bus = dbus.SystemBus()
    agent = dbus.Interface(bus.get_object(unique_name, AGENT_PATH), AGENT_IFACE)

    # ── 1. RequestConfirmation: BlueZ спрашивает подтверждение passkey ──
    outcome = {}

    def call_confirmation():
        try:
            agent.RequestConfirmation(dbus.ObjectPath(FAKE_DEVICE), dbus.UInt32(123456))
            outcome["ok"] = True
        except dbus.exceptions.DBusException as exc:
            outcome["ok"] = False
            outcome["error"] = str(exc)

    thread = threading.Thread(target=call_confirmation, daemon=True)
    thread.start()

    event = helper.read_until(
        lambda e: e.get("ev") == "agent" and e.get("request") == "RequestConfirmation",
        10)
    check("запрос RequestConfirmation дошёл до stdout", event is not None)
    if event is not None:
        check("адрес устройства разобран из пути",
              event.get("address") == "AA:BB:CC:DD:EE:FF", event.get("address"))
        check("passkey передан", event.get("passkey") == 123456, event.get("passkey"))

    helper.send(cmd="agent_reply", address="AA:BB:CC:DD:EE:FF", accept=True, value="")
    thread.join(timeout=10)
    check("метод вернулся после agent_reply", outcome.get("ok") is True,
          outcome.get("error", ""))

    # ── 2. RequestConfirmation с отказом → BlueZ должен получить Rejected ──
    outcome2 = {}

    def call_and_reject():
        try:
            agent.RequestConfirmation(dbus.ObjectPath(FAKE_DEVICE), dbus.UInt32(654321))
            outcome2["ok"] = True
        except dbus.exceptions.DBusException as exc:
            outcome2["ok"] = False
            outcome2["name"] = exc.get_dbus_name()

    thread2 = threading.Thread(target=call_and_reject, daemon=True)
    thread2.start()
    event2 = helper.read_until(
        lambda e: e.get("ev") == "agent" and e.get("request") == "RequestConfirmation"
        and e.get("passkey") == 654321, 10)
    check("второй запрос дошёл", event2 is not None)
    helper.send(cmd="agent_reply", address="AA:BB:CC:DD:EE:FF", accept=False, value="")
    thread2.join(timeout=10)
    check("отказ ушёл в BlueZ как Rejected",
          outcome2.get("name") == "org.bluez.Error.Rejected", outcome2)

    # ── 3. RequestPinCode с вводом PIN ──
    outcome3 = {"value": None}

    def call_pin():
        try:
            outcome3["value"] = str(agent.RequestPinCode(
                dbus.ObjectPath(FAKE_DEVICE), dbus.String("bredr")))
        except dbus.exceptions.DBusException as exc:
            outcome3["error"] = str(exc)

    thread3 = threading.Thread(target=call_pin, daemon=True)
    thread3.start()
    event3 = helper.read_until(
        lambda e: e.get("ev") == "agent" and e.get("request") == "RequestPinCode", 10)
    check("запрос RequestPinCode дошёл", event3 is not None)
    check("вид запроса — pin", event3 is not None and event3.get("kind") == "pin",
          event3.get("kind") if event3 else "")
    helper.send(cmd="agent_reply", address="AA:BB:CC:DD:EE:FF", accept=True, value="1234")
    thread3.join(timeout=10)
    check("PIN вернулся в BlueZ", outcome3.get("value") == "1234", outcome3)

    # ── 4. Cancel: BlueZ отменяет запрос ──
    outcome4 = {}

    def call_cancel_wait():
        try:
            agent.RequestAuthorization(dbus.ObjectPath(FAKE_DEVICE))
            outcome4["ok"] = True
        except dbus.exceptions.DBusException as exc:
            outcome4["name"] = exc.get_dbus_name()

    thread4 = threading.Thread(target=call_cancel_wait, daemon=True)
    thread4.start()
    event4 = helper.read_until(
        lambda e: e.get("ev") == "agent" and e.get("request") == "RequestAuthorization", 10)
    check("запрос RequestAuthorization дошёл", event4 is not None)
    agent.Cancel()
    helper.read_until(lambda e: e.get("ev") == "agent" and e.get("request") == "Cancel", 5)
    thread4.join(timeout=10)
    check("после Cancel метод вернул Canceled",
          outcome4.get("name") == "org.bluez.Error.Canceled", outcome4)

    helper.close()

    failed = [r for r in results if not r[1]]
    print("---")
    print("ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ" if not failed else "ПРОВАЛЕНО: %d" % len(failed))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
