import QtQuick
import ".."
import "../../singletons"

// Индикатор Wi-Fi: глифы Material Design Icons из Nerd Font
// (nf-md-wifi_strength_*). Состояния:
//   * включён и подключён — деления по уровню сигнала (strength_1..4);
//   * включён, но не подключён — wifi_strength_outline (пустые деления);
//   * выключен — wifi_off (перечёркнутый значок).
Item {
    id: root

    property bool wifiEnabled: true
    property bool connected: false
    // Уровень сигнала 0–4 (как у wifiIconStrength: 0 — нет данных, 4 — максимум).
    // Показываем три градации: минимальную, среднюю и максимальную.
    property int signal: 0

    // Иконка в кружке плитки: заливка кружка — accent, поэтому цвета
    // подбираем под него.
    property bool onAccent: false

    implicitWidth: 18
    implicitHeight: 18

    readonly property int level: {
        const value = Math.max(0, Math.min(4, signal));
        if (value <= 1)
            return 1;
        if (value === 2)
            return 2;
        return 3;
    }

    // MDI-кодпоинты лежат выше BMP (U+F091E..), а в QML "\uf0920" — это две
    // UTF-16 единицы, а не кодпоинт: строку собираем через String.fromCodePoint.
    // Набор проверен отрисовкой сетки с подписями: на каждый уровень сигнала
    // идёт тройка «чистый / с „!“ / с замком», порядок такой:
    //   F091E..F0921 — strength_1..4  (деления заполняются),
    //   F0922..F0925 — варианты без заливки/предупреждения,
    //   F0929..F092D — контур, «!», замок, off...; F092D — перечёркнутый.
    // Берём чистые деления 1/2/3, пустой контур и перечёркнутый.
    readonly property string glyphS1: String.fromCodePoint(0xF091E)
    readonly property string glyphS2: String.fromCodePoint(0xF091F)
    readonly property string glyphS3: String.fromCodePoint(0xF0920)
    readonly property string glyphEmpty: String.fromCodePoint(0xF0921)
    readonly property string glyphOff: String.fromCodePoint(0xF092D)

    // Уровень 0–4, как отдаёт сервис: 0 — нет данных, 4 — максимум.
    readonly property string glyph: {
        if (!wifiEnabled)
            return glyphOff;
        // Не подключён — пустые деления.
        if (!connected)
            return glyphEmpty;
        if (level >= 3)
            return glyphS3;
        if (level === 2)
            return glyphS2;
        return glyphS1;
    }

    Text {
        anchors.fill: parent
        text: root.glyph
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: {
            if (!root.wifiEnabled)
                return String(Theme.quickTextDim);
            if (!root.connected)
                return root.onAccent ? String(Theme.menuSurface)
                                     : String(Theme.quickTextDim);
            return root.onAccent ? String(Theme.quickIconOn)
                                 : String(Theme.quickText);
        }
        font.family: Theme.iconFontFamily
        // Кегль меньше рамки: MDI-глифы занимают почти весь em, без запаса
        // они упирались бы в края и выглядели обрезанными.
        font.pixelSize: Math.max(10, Math.round(root.height * 0.78))
    }
}
