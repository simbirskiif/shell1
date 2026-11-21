import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Индикатор Wi-Fi: деления сигнала глифами Material Design Icons из Nerd Font
// (nf-md-wifi_strength_*).
//
// Expressive: у подключённой сети круглый орб превращается в «печенье»
// (или другой выразительный контур, заданный connectedShape) и заливается
// цветом-контейнером. У выключенной/неизвестной сети — спокойный круг
// с тонкой обводкой. API прежний, новые свойства — только оформление.
//
//   level 0 — пустой контур (уровень неизвестен),
//   level 1..3 — деления по силе сигнала.
//
// Режим offMode рисует значок выключенного radio (nf-md-wifi_off).
Item {
    id: root

    // Уровень сигнала 0–4, как отдаёт сервис (0 — нет данных, 4 — максимум).
    property int signal: 0

    // Орб-подложка подключения — как у иконок в списках панелей.
    property bool showRing: false
    property bool connected: false

    // Цвета и форма орба: панель подбирает контрастную пару под свою строку.
    property color ringColor: root.connected ? Theme.tertiaryContainer
                                             : Theme.surfaceContainerHighest
    property color ringInk: root.connected ? Theme.scheme.onTertiaryContainer
                                           : Theme.scheme.onSurfaceVariant
    property string connectedShape: "cookie"
    property string idleShape: "circle"

    // Значок в кружке плитки: заливка — accent, поэтому цвета подбираем под неё.
    property bool onAccent: false

    // Значок выключенного Wi-Fi вместо делений.
    property bool offMode: false

    // Приглушённый значок (выключенное radio в баре и шапке панели).
    property bool dim: false

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

    // Орб: неактивный — круг с тонкой обводкой, подключённый — выразительный
    // контур без обводки (держит форму и цвет, а не рамку).
    MorphShape {
        visible: root.showRing
        anchors.fill: parent
        shape: root.connected ? root.connectedShape : root.idleShape
        color: root.ringColor
        modulation: 1
        borderWidth: root.connected ? 0 : 1
        borderColor: Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // Кегль значка — как у глифов в остальных виджетах: 15 в кружке строки,
    // 16 в кружке плитки, 14 в баре, 34 на заглушке. Контексты передают своё.
    property int glyphSize: 15

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: {
            if (root.onAccent)
                return Theme.scheme.onPrimary;
            if (root.showRing)
                return root.connected ? root.ringInk : Theme.scheme.onSurfaceVariant;
            if (root.dim)
                return Theme.scheme.onSurfaceVariant;
            return Theme.scheme.onSurface;
        }
        font.family: Theme.iconFontFamily
        font.pixelSize: root.glyphSize
        Behavior on color { ColorAnimation { duration: 140 } }
    }
}
