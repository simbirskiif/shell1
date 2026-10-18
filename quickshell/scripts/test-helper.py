#!/usr/bin/env python3
"""Тест-драйвер helper'а: говорит с ним по протоколу и печатает отчёт.

Запускается вручную/из тестов, в рабочем пути не используется.
Использование:
  ./test-helper.py snapshot
  ./test-helper.py scan 12
  ./test-helper.py power on|off
  ./test-helper.py pair AA:BB:...
  ./test-helper.py connect AA:BB:...
  ./test-helper.py disconnect AA:BB:...
  ./test-helper.py remove AA:BB:...
"""

import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "qs-bluetooth-helper.py")


class Driver:
    def __init__(self):
        self.proc = subprocess.Popen(
            [sys.executable, HELPER],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, bufsize=1)
        self.counter = 0
        self.events = []
        self.ready = False

    def send(self, **cmd):
        self.counter += 1
        cmd.setdefault("id", str(self.counter))
        self.proc.stdin.write(json.dumps(cmd) + "\n")
        self.proc.stdin.flush()
        return cmd["id"]

    def pump(self, seconds):
        """Читает события заданное время, возвращает список новых."""
        deadline = time.time() + seconds
        fresh = []
        import select
        while time.time() < deadline:
            if select.select([self.proc.stdout], [], [], 0.2)[0]:
                line = self.proc.stdout.readline()
                if not line:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except ValueError:
                    print("!! не JSON: %r" % line)
                    continue
                self.events.append(event)
                fresh.append(event)
                self.print_event(event)
                if event.get("ev") == "ready":
                    self.ready = True
        return fresh

    def wait_result(self, req_id, seconds):
        """Ждёт result с нужным id, попутно печатая события."""
        deadline = time.time() + seconds
        import select
        while time.time() < deadline:
            if select.select([self.proc.stdout], [], [], 0.2)[0]:
                line = self.proc.stdout.readline()
                if not line:
                    break
                line = line.strip()
                if not line:
                    continue
                event = json.loads(line)
                self.events.append(event)
                self.print_event(event)
                if event.get("ev") == "result" and event.get("id") == req_id:
                    return event
        return None

    def print_event(self, event):
        ev = event.get("ev")
        if ev == "ready":
            print("  ready adapter=%s adapters=%d devices=%d"
                  % (event.get("adapter"), len(event.get("adapters", [])),
                     len(event.get("devices", []))))
            for dev in event.get("devices", []):
                print("    %s «%s» paired=%s connected=%s rssi=%s"
                      % (dev.get("Address"), dev.get("Alias"),
                         dev.get("Paired"), dev.get("Connected"), dev.get("RSSI")))
        elif ev == "device_added":
            p = event.get("props", {})
            print("  + устройство %s «%s» rssi=%s"
                  % (p.get("Address"), p.get("Alias"), p.get("RSSI")))
        elif ev == "device":
            p = event.get("props", {})
            print("  ~ %s «%s» connected=%s paired=%s trusted=%s battery=%s"
                  % (p.get("Address"), p.get("Alias"), p.get("Connected"),
                     p.get("Paired"), p.get("Trusted"), p.get("Battery")))
        elif ev == "device_removed":
            print("  - устройство %s" % event.get("path"))
        elif ev == "adapter":
            p = event.get("props", {})
            print("  адаптер powered=%s discovering=%s powerState=%s"
                  % (p.get("Powered"), p.get("Discovering"), p.get("PowerState")))
        elif ev == "phase":
            print("  ФАЗА %s: %s" % (event.get("address"), event.get("phase")))
        elif ev == "agent":
            print("  АГЕНТ %s от %s %s"
                  % (event.get("request"), event.get("address"),
                     {k: v for k, v in event.items()
                      if k not in ("ev", "request", "address")}))
        elif ev == "agent_registered":
            print("  агент зарегистрирован: %s" % event.get("capability"))
        elif ev == "result":
            print("  RESULT id=%s ok=%s %s%s"
                  % (event.get("id"), event.get("ok"),
                     ("address=%s " % event.get("address")) if event.get("address") else "",
                     ("error=%s" % event.get("error")) if event.get("error") else ""))
        else:
            print("  %s %s" % (ev, {k: v for k, v in event.items() if k != "ev"}))

    def close(self):
        try:
            self.send(cmd="quit")
            time.sleep(0.3)
        except Exception:                               # noqa: BLE001
            pass
        self.proc.terminate()
        try:
            self.proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.proc.kill()
        err = self.proc.stderr.read()
        if err:
            print("--- stderr helper ---")
            print(err.strip())


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    action = sys.argv[1]
    arg = sys.argv[2] if len(sys.argv) > 2 else None
    driver = Driver()
    driver.pump(2.0)
    if not driver.ready:
        print("!! helper не прислал ready")
        driver.close()
        return 1

    if action == "snapshot":
        rid = driver.send(cmd="snapshot")
        driver.wait_result(rid, 5)
    elif action == "power":
        value = (arg or "on") == "on"
        rid = driver.send(cmd="power", value=value)
        driver.wait_result(rid, 15)
        driver.pump(2)
    elif action == "scan":
        rid = driver.send(cmd="scan", start=True)
        driver.wait_result(rid, 10)
        driver.pump(float(arg or 12))
        rid = driver.send(cmd="scan", start=False)
        driver.wait_result(rid, 10)
    elif action in ("pair", "connect", "disconnect", "remove", "trust"):
        rid = driver.send(cmd=action, address=arg)
        driver.wait_result(rid, 50)
    else:
        print("неизвестное действие: %s" % action)
        driver.close()
        return 2

    driver.close()
    print("--- итого событий: %d ---" % len(driver.events))
    return 0


if __name__ == "__main__":
    sys.exit(main())
