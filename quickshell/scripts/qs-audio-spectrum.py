#!/usr/bin/env python3
"""Реальный спектр системного аудиопотока для иконки и окна плеера.

Читает монитора дефолтного sink'а через parec (сырой PCM s16le, моно, 22050 Гц),
считает БПФ на чистом Python (numpy в системе нет) и печатает по одной
JSON-строке с уровнем каждой полосы 0..1. Ошибки и диагностика — в stderr,
stdout остаётся протоколом.

Это отдельный процесс, а не QML-таймер: БПФ и чтение PCM не должны
блокировать UI-поток оболочки.
"""

import json
import math
import signal
import struct
import subprocess
import sys
import time

RATE = 22050
FFT_SIZE = 1024
BANDS = 16
MIN_HZ = 40.0
MAX_HZ = 10000.0
# Ниже этого уровня полоса считается тишиной; выше — полной шкалой.
FLOOR_DB = -65.0

running = True


def stop(_signum, _frame):
    global running
    running = False


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)


def make_fft(size):
    """Итеративное БПФ с заранее посчитанными поворотами и бит-реверсом."""
    levels = size.bit_length() - 1
    rev = [0] * size
    for i in range(size):
        value = i
        result = 0
        for _ in range(levels):
            result = (result << 1) | (value & 1)
            value >>= 1
        rev[i] = result

    cos_table = [math.cos(2.0 * math.pi * i / size) for i in range(size // 2)]
    sin_table = [math.sin(2.0 * math.pi * i / size) for i in range(size // 2)]

    def transform(values):
        data = [complex(values[rev[i]], 0.0) for i in range(size)]
        length = 2
        while length <= size:
            half = length // 2
            step = size // length
            for start in range(0, size, length):
                index = 0
                for offset in range(start, start + half):
                    other = offset + half
                    twiddle = complex(cos_table[index], -sin_table[index])
                    value = data[other] * twiddle
                    data[other] = data[offset] - value
                    data[offset] += value
                    index += step
            length *= 2
        return data

    return transform


def band_edges(size):
    """Границы полос в бинах: логарифмическая шкала от MIN_HZ до MAX_HZ."""
    edges = []
    for i in range(BANDS + 1):
        hz = MIN_HZ * ((MAX_HZ / MIN_HZ) ** (i / BANDS))
        bin_index = int(round(hz * size / RATE))
        edges.append(max(1, min(size // 2 - 1, bin_index)))
    # Гарантируем хотя бы один бин в полосе.
    for i in range(1, len(edges)):
        if edges[i] <= edges[i - 1]:
            edges[i] = min(size // 2 - 1, edges[i - 1] + 1)
    return edges


def read_exact(stream, size):
    chunks = []
    remaining = size
    while remaining > 0 and running:
        chunk = stream.read(remaining)
        if not chunk:
            return b"".join(chunks)
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def run_analyzer():
    fft = make_fft(FFT_SIZE)
    edges = band_edges(FFT_SIZE)
    window = [0.5 - 0.5 * math.cos(2.0 * math.pi * i / (FFT_SIZE - 1))
              for i in range(FFT_SIZE)]
    smooth = [0.0] * BANDS
    scale = 2.0 / FFT_SIZE

    try:
        capture = subprocess.Popen(
            ["parec",
             "--device=@DEFAULT_MONITOR@",
             "--format=s16le",
             "--rate=%d" % RATE,
             "--channels=1",
             "--raw",
             "--latency-msec=25",
             "--client-name=quickshell-spectrum"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
        )
    except OSError as error:
        print("parec не запущен: %s" % error, file=sys.stderr)
        return

    try:
        while running:
            payload = read_exact(capture.stdout, FFT_SIZE * 2)
            if len(payload) < FFT_SIZE * 2:
                break
            samples = struct.unpack("<%dh" % FFT_SIZE, payload)
            mean = sum(samples) / FFT_SIZE
            values = [((samples[i] - mean) / 32768.0) * window[i]
                      for i in range(FFT_SIZE)]
            spectrum = fft(values)
            levels = []
            for band in range(BANDS):
                low = edges[band]
                high = max(low + 1, edges[band + 1])
                peak = 0.0
                for index in range(low, high):
                    magnitude = abs(spectrum[index]) * scale
                    if magnitude > peak:
                        peak = magnitude
                db = 20.0 * math.log10(peak + 1e-9)
                level = max(0.0, min(1.0, (db - FLOOR_DB) / -FLOOR_DB))
                # Быстрый подъём, плавное падение — спектр не дёргается.
                previous = smooth[band]
                smooth[band] = level if level > previous else previous * 0.78 + level * 0.22
                levels.append(round(smooth[band], 3))
            print(json.dumps(levels), flush=True)
    finally:
        try:
            capture.terminate()
            capture.wait(timeout=1.0)
        except Exception:
            pass


def main():
    while running:
        run_analyzer()
        if not running:
            break
        # parec мог умереть вместе с PipeWire/PulseAudio — перезапускаем,
        # но не в тесном цикле.
        time.sleep(1.0)


if __name__ == "__main__":
    main()
