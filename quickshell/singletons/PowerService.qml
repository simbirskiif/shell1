pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Реальный backend батареи и режимов питания.
//
// Батарея — нативный модуль Quickshell.Services.UPower: значения приходят
// событиями по системному D-Bus, опрашивать upower из Process не нужно.
//
// Режимы — power-profiles-daemon через нативный PowerProfiles. Это тот самый
// демон, которым управляют настройки питания GNOME (power-saver / balanced /
// performance), поэтому отдельный CLI (powerprofilesctl, gnome-power-manager)
// не нужен и в системе может отсутствовать. У PowerProfiles нет свойства
// «доступен»: без демона profile молча остаётся Balanced, а запись уходит
// только в лог. Поэтому доступность один раз проверяем D-Bus-запросом к
// org.freedesktop.UPower.PowerProfiles — он же поднимает демон, если тот
// активируется по D-Bus. Пока проверка не прошла или демон недоступен,
// панель батареи показывает плашку вместо выбора режима.
//
// Правило: ни одно значение не выдумывается. Нет батареи — present = false,
// нет демона — profilesAvailable = false, и фронт честно это показывает.
Singleton {
    id: root

    // ───────────── батарея ─────────────

    // Агрегат, которым пользуется и сама система: уровень, время, энергия.
    readonly property UPowerDevice battery: UPower.displayDevice

    // Модель и здоровье есть только у конкретной батареи (BAT0), у агрегата
    // их нет: берём первую батарею ноутбука из списка устройств UPower.
    readonly property UPowerDevice primaryBattery: {
        const devices = UPower.devices.values;
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i] && devices[i].isLaptopBattery)
                return devices[i];
        }
        return null;
    }

    // displayDevice отдаётся до первого GetAll: до ready значения нулевые,
    // и показывать «0%» вместо «читаю» нельзя.
    readonly property bool ready: root.battery !== null && root.battery.ready
    // isLaptopBattery — единственная надёжная проверка «это батарея ноутбука».
    readonly property bool present: root.ready
        && (root.primaryBattery !== null || root.battery.isLaptopBattery)

    // percentage у модуля — доля 0..1 (UPower отдаёт проценты, модуль делит
    // их на 100), поэтому наружу отдаём целые проценты.
    readonly property int level: root.present
        ? Math.max(0, Math.min(100, Math.round(root.battery.percentage * 100))) : 0

    readonly property int deviceState: root.present
        ? root.battery.state : UPowerDeviceState.Unknown
    readonly property bool charging: root.deviceState === UPowerDeviceState.Charging
                                  || root.deviceState === UPowerDeviceState.PendingCharge
    readonly property bool fullyCharged: root.deviceState === UPowerDeviceState.FullyCharged
    // Питание от сети (адаптер подключён), а не от батареи.
    readonly property bool onAc: !UPower.onBattery

    readonly property real energy: root.present ? root.battery.energy : 0
    readonly property real energyCapacity: root.present ? root.battery.energyCapacity : 0
    // changeRate положителен при зарядке: для «потребления» берём модуль.
    readonly property real powerDraw: root.present ? Math.abs(root.battery.changeRate) : 0

    // Источник подробностей: конкретная батарея, иначе агрегат.
    readonly property UPowerDevice detailDevice: root.primaryBattery !== null
        ? root.primaryBattery : root.battery
    readonly property bool detailReady: root.detailDevice !== null && root.detailDevice.ready
    readonly property int health: root.detailReady && root.detailDevice.healthSupported
        ? Math.round(root.detailDevice.healthPercentage) : -1
    readonly property string model: root.detailReady ? root.detailDevice.model : ""

    readonly property string stateText: {
        if (!root.present)
            return I18n.tr("power.state.none");
        if (root.charging)
            return I18n.tr("power.state.charging");
        if (root.fullyCharged)
            return I18n.tr("power.state.full");
        if (root.deviceState === UPowerDeviceState.Empty)
            return I18n.tr("power.state.empty");
        if (root.onAc)
            return I18n.tr("power.state.plugged");
        if (root.deviceState === UPowerDeviceState.Discharging
                || root.deviceState === UPowerDeviceState.PendingDischarge)
            return I18n.tr("power.state.discharging");
        return UPowerDeviceState.toString(root.deviceState);
    }

    // Время берём из того поля, которое соответствует состоянию: UPower
    // обнуляет timeToEmpty при зарядке и timeToFull при разрядке.
    readonly property string timeText: {
        if (!root.present)
            return "";
        if (root.charging && root.battery.timeToFull > 0)
            return I18n.tr("power.time.untilFull",
                           { time: formatDuration(root.battery.timeToFull) });
        if (!root.charging && !root.fullyCharged && root.battery.timeToEmpty > 0)
            return I18n.tr("power.time.remaining",
                           { time: formatDuration(root.battery.timeToEmpty) });
        return "";
    }

    function formatDuration(seconds) {
        const total = Math.round(seconds / 60);
        if (total <= 0)
            return "";
        const hours = Math.floor(total / 60);
        const minutes = total % 60;
        if (hours <= 0)
            return I18n.trn("power.duration.minutes", minutes);
        if (minutes === 0)
            return I18n.trn("power.duration.hours", hours);
        return I18n.tr("power.duration.hoursMinutes",
                       { hours: hours, minutes: minutes });
    }

    readonly property string energyText: root.present && root.energyCapacity > 0
        ? root.energy.toFixed(1) + " / " + root.energyCapacity.toFixed(1) + " Wh" : ""
    readonly property string powerText: root.present && root.powerDraw > 0
        ? root.powerDraw.toFixed(1) + " W" : ""
    readonly property string healthText: root.health >= 0 ? root.health + "%" : ""
    readonly property string sourceText: root.present
        ? (root.onAc ? I18n.tr("power.source.ac") : I18n.tr("power.source.battery")) : ""

    // ───────────── режимы питания ─────────────

    // Доступность power-profiles-daemon: false до первой проверки и при
    // отсутствии демона. Пока false, фронт не рисует сегменты режима.
    property bool profilesAvailable: false

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    // Без демона profile — это умолчание Balanced, а не состояние системы.
    readonly property string profileName: root.profilesAvailable
        ? PowerProfile.toString(PowerProfiles.profile) : "unknown"
    readonly property int degradationReason: PowerProfiles.degradationReason

    // Сегменты режима: значение enum + подпись. Порядок как в GNOME.
    readonly property var profiles: [
        { value: PowerProfile.PowerSaver, label: I18n.tr("power.profile.saver") },
        { value: PowerProfile.Balanced, label: I18n.tr("power.profile.balanced") },
        { value: PowerProfile.Performance, label: I18n.tr("power.profile.performance") }
    ]

    // Performance есть не на каждом железе: без него сегмент неактивен.
    function isProfileAvailable(value) {
        if (value === PowerProfile.Performance)
            return root.hasPerformanceProfile;
        return true;
    }

    function setProfile(value) {
        if (!root.profilesAvailable || !root.isProfileAvailable(value))
            return;
        if (PowerProfiles.profile === value)
            return;
        PowerProfiles.profile = value;
    }

    function setProfileByName(name) {
        const key = (name || "").toLowerCase().replace(/[\s_-]/g, "");
        if (key === "saver" || key === "powersaver")
            root.setProfile(PowerProfile.PowerSaver);
        else if (key === "balanced")
            root.setProfile(PowerProfile.Balanced);
        else if (key === "performance" || key === "perf")
            root.setProfile(PowerProfile.Performance);
    }

    readonly property string degradationText: {
        if (root.degradationReason === PerformanceDegradationReason.LapDetected)
            return I18n.tr("power.degradation.lap");
        if (root.degradationReason === PerformanceDegradationReason.HighTemperature)
            return I18n.tr("power.degradation.highTemp");
        return "";
    }

    // Чужие holds объясняют, почему выбранный режим «сам» возвращается.
    readonly property string holdsText: {
        const holds = PowerProfiles.holds;
        if (!holds || holds.length === 0)
            return "";
        const names = [];
        for (let i = 0; i < holds.length; ++i) {
            const name = holds[i].applicationId || holds[i].reason || "";
            if (name !== "" && names.indexOf(name) < 0)
                names.push(name);
        }
        return names.length > 0 ? I18n.tr("power.heldBy", { names: names.join(", ") }) : "";
    }

    // Один D-Bus-запрос вместо таймера: сервиса нет — значит нет и режимов.
    // Запрос заодно активирует демон, если он стартует по D-Bus. busctl —
    // единственный внешний вызов во всём сервисе: у PowerProfiles в QML нет
    // свойства «подключён», а без него запись режима молча уходит в лог.
    Process {
        id: probe

        command: ["busctl", "--system", "get-property",
                  "org.freedesktop.UPower.PowerProfiles",
                  "/org/freedesktop/UPower/PowerProfiles",
                  "org.freedesktop.UPower.PowerProfiles", "ActiveProfile"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {}

        onExited: (exitCode, exitStatus) => {
            root.profilesAvailable = exitCode === 0;
        }
    }

    function probeProfiles() {
        if (probe.running)
            return;
        probe.running = true;
    }

    // Демон может появиться позже (поставили, включили): дешёвая проверка
    // при каждом открытии панели батареи, без опроса по таймеру.
    Connections {
        target: UiState

        function onPanelChanged() {
            if (UiState.panel === "battery")
                root.probeProfiles();
        }
    }

    Component.onCompleted: root.probeProfiles()
}
