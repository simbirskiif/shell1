import QtQuick
import ".."
import "../../singletons"

// Индикатор Wi-Fi: деления сигнала глифами Material Design Icons из Nerd Font
// (nf-md-wifi_strength_*). Как у иконок строки Bluetooth, у подключённой сети
// есть круглая подложка и кольцо (showRing).
//
//   level 0 — пустой контур (уровень неизвестен),
//   level 1..3 — деления по силе сигнала.
//
// Режим offMode рисует значок выключенного radio (nf-md-wifi_off).
Item {
    id: root

    // Уровень сигнала 0–4, как отдаёт сервис (0 — нет данных, 4 — максимум).
    property int signal: 0

    // Подложка и кольцо подключения — как у PanelIcon в списках.
    property bool showRing: false
    property bool connected: false

    // Значок в кружке плитки: заливка — accent, поэтому цвета подбираем под неё.
    property bool onAccent: false

    // Значок выключенного Wi-Fi вместо делений.
    property bool offMode: false

    // Приглушённый значок (выключенное radio в баре и шапке панели).
    property bool dim: false

    // Доля высоты, которую занимает глиф (1 — как в баре и шапке).
    property real sizeScale: 1

    implicitWidth: 34
    implicitHeight: 34

    // Показываем три градации: минимальную, среднюю и максимальную.
    readonly property int level: {
        const value = Math.max(0, Math.min(4, signal));
        if (value <= 0)
            return 0;
        if (value <= 1)
            return 1;
        if (value === 2)
            return 2;
        return 3;
    }

    // Кодпоинты MDI лежат выше BMP, а в QML "\uf0922" — это две UTF-16
    // единицы, а не кодпоинт: строку собираем через String.fromCodePoint.
    // Карта nf-md-wifi_strength_* (по шпаргалке Nerd Font):
    //   F0922 strength_2, F0925 strength_3, F0928 strength_4,
    //   F092F strength_outline, F05AA wifi_off.
    readonly property string glyphS1: String.fromCodePoint(0xF0922)
    readonly property string glyphS2: String.fromCodePoint(0xF0925)
    readonly property string glyphS3: String.fromCodePoint(0xF0928)
    readonly property string glyphEmpty: String.fromCodePoint(0xF092F)
    readonly property string glyphOff: String.fromCodePoint(0xF05AA)

    readonly property string glyph: {
        if (offMode)
            return glyphOff;
        if (level >= 3)
            return glyphS3;
        if (level === 2)
            return glyphS2;
        if (level === 1)
            return glyphS1;
        return glyphEmpty;
    }

    Rectangle {
        visible: root.showRing
        anchors.fill: parent
        radius: width / 2
        color: root.connected ? Theme.quickTileActive : Theme.quickCircleOff
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
    }

    Rectangle {
        visible: root.showRing
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: root.connected ? 1 : 0
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveStandard
            }
        }
    }

    // Кегль и рамка текста. В кружке строки значок занимает примерно половину
    // диаметра (как глифы в PanelIcon), без кружка — почти всю рамку.
    readonly property int glyphSize: Math.max(9, Math.round(root.height * 0.85 * root.sizeScale))

    // Метрики глифа приходят в физических пикселях, а размеры элементов — в
    // логических: приводим к логическим, иначе сдвиг выходит за границы.
    readonly property real dpr: (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1)

    // Границы самого рисунка глифа: MDI-значки сидят в em не по центру,
    // поэтому центрируем по видимым границам, а не по рамке текста.
    TextMetrics {
        id: metrics
        font.family: Theme.iconFontFamily
        font.pixelSize: root.glyphSize
        text: root.glyph
    }

    Text {
        id: glyphText
        text: root.glyph
        color: {
            if (root.dim)
                return Theme.quickTextDim;
            if (root.onAccent)
                return Theme.quickIconOn;
            if (root.showRing)
                return root.connected ? Theme.accent : Theme.quickText;
            return Theme.quickText;
        }
        font.family: Theme.iconFontFamily
        font.pixelSize: root.glyphSize

        // Рисунок внутри рамки текста: сдвигаем рамку так, чтобы центр
        // рисунка совпал с центром контейнера.
        readonly property rect rawInk: metrics.tightBoundingRect
        readonly property real inkX: rawInk.x / root.dpr
        readonly property real inkY: rawInk.y / root.dpr
        readonly property real inkW: rawInk.width / root.dpr
        readonly property real inkH: rawInk.height / root.dpr

        x: Math.round((root.width - width) / 2 - (inkX + inkW / 2))
        y: Math.round((root.height - height) / 2 - (inkY + inkH / 2))
    }
}
