import QtQuick
import ".."
import "../../singletons"

// Одна сессия истории конфиденциальности. «Пакет» — непрерывный период
// использования приложения с устройством; короткие паузы уже склеены
// PrivacyService.
Item {
    id: root

    required property string device
    required property var apps
    required property real start
    required property real end

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 52

    readonly property bool microphone: root.device === "microphone"
    readonly property bool camera: root.device === "camera"

    readonly property string deviceTitle: root.microphone ? "Microphone"
        : root.camera ? "Camera" : "Location"

    readonly property string title: root.apps.length > 0
        ? root.apps.join(", ") : root.deviceTitle

    readonly property string glyph: root.microphone ? SystemIcons.microphoneGlyph
        : root.camera ? SystemIcons.cameraGlyph : SystemIcons.locationGlyph

    readonly property color accent: root.microphone ? SystemIcons.microphoneColor
        : root.camera ? SystemIcons.cameraColor : SystemIcons.locationColor

    readonly property color onAccent: root.microphone ? SystemIcons.microphoneOnColor
        : root.camera ? SystemIcons.cameraOnColor : SystemIcons.locationOnColor

    function twoDigits(value) {
        return value < 10 ? "0" + value : String(value);
    }

    function clock(ms) {
        const date = new Date(ms);
        return root.twoDigits(date.getHours()) + ":" + root.twoDigits(date.getMinutes());
    }

    function dayText(ms) {
        const date = new Date(ms);
        const now = new Date();
        const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const day = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
        const dayMs = 86400000;
        if (day === startOfDay)
            return "";
        if (day === startOfDay - dayMs)
            return "Yesterday ";
        return root.twoDigits(date.getDate()) + "." + root.twoDigits(date.getMonth() + 1) + " ";
    }

    function durationText() {
        const seconds = Math.max(1, Math.round((root.end - root.start) / 1000));
        if (seconds < 60)
            return seconds + " s";
        const minutes = Math.round(seconds / 60);
        if (minutes < 60)
            return minutes + " min";
        const hours = Math.floor(minutes / 60);
        const rest = minutes % 60;
        return hours + " h" + (rest > 0 ? " " + rest + " min" : "");
    }

    readonly property string details: {
        const prefix = root.apps.length > 0 ? root.deviceTitle + " · " : "";
        // В пределах одной минуты «20:12–20:12» ничего не добавляет —
        // оставляем только начало и длительность.
        const sameMinute = Math.floor(root.start / 60000) === Math.floor(root.end / 60000);
        const time = sameMinute
            ? root.clock(root.start)
            : root.clock(root.start) + "–" + root.clock(root.end);
        return prefix + root.dayText(root.start) + time + " · " + root.durationText();
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.md
        color: Theme.surfaceContainerLow
    }

    PrivacyOrb {
        id: orb

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        icon: root.glyph
        accent: root.accent
        onAccent: root.onAccent
        animated: false
        interactive: false
        visualSize: 28
        hitSize: 28
    }

    Column {
        anchors.left: orb.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.title
            color: Theme.scheme.onSurface
            font: Theme.typeLabelLarge
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.details
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelSmall
            elide: Text.ElideRight
        }
    }
}
