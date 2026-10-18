#!/usr/bin/env bash
# Компиляция .frag в .qsb для Qt Quick ShaderEffect.
# qsb ищется в PATH, QSB_DIR, /usr/lib/qt6/bin и /usr/lib/qt6/bin/qsb.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
qsb="${QSB:-}"
if [[ -z "$qsb" ]]; then
    if command -v qsb >/dev/null 2>&1; then
        qsb="$(command -v qsb)"
    elif [[ -x /usr/lib/qt6/bin/qsb ]]; then
        qsb=/usr/lib/qt6/bin/qsb
    else
        echo "qsb не найден; установите qt6-shadertools" >&2
        exit 1
    fi
fi

shopt -s nullglob
for frag in "$root"/materials/*/*.frag; do
    out="${frag}.qsb"
    echo "qsb: ${frag#"$root"/} -> ${out#"$root"/}"
    "$qsb" --qt6 -o "$out" "$frag"
done
