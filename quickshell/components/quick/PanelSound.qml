import QtQuick
import ".."
import "../../singletons"

// Панель «Звук»: две вкладки — «Speakers» (вывод) и «Microphone» (вход).
// На вкладке вывода ещё и громкость каждого приложения: потоки
// воспроизведения играют в вывод, к микрофону они не относятся.
// Данные и действия — в AudioService; здесь только отображение.
Item {
    id: root

    signal backRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: I18n.tr("quick.tile.sound")
            // Тумблер в шапке — mute вывода: отдельного «выключить звук
            // целиком» у PipeWire нет. Без backend переключать нечего.
            checked: !AudioService.outputMuted
            switchable: AudioService.available
            onBackRequested: root.backRequested()
            onToggled: AudioService.toggleOutputMute()
        }

        // Разделитель шапки m3 — outline-variant.
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PanelDisabled {
            width: parent.width
            readonly property bool shown: !AudioService.available
            visible: shown
            height: shown ? implicitHeight : 0
            icon: SystemIcons.soundGlyph
            title: I18n.tr("quick.audio.unavailable")
            description: I18n.tr("quick.audio.pipewire")
            actionText: ""
            // Действия, которое можно предложить, нет — кнопку не рисуем.
            showAction: false
        }

        Column {
            id: availableContent
            width: parent.width
            spacing: 0
            readonly property bool shown: AudioService.available
            visible: shown
            height: shown ? implicitHeight : 0

            PanelTabs {
                width: parent.width
                tabs: [
                    { key: "output", title: I18n.tr("quick.sound.speakers") },
                    { key: "input", title: I18n.tr("quick.sound.microphone") }
                ]
                current: UiState.soundTab
                onSelected: key => {
                    UiState.setSoundTab(key);
                }
            }

            // --- вывод -------------------------------------------------
            Column {
                id: outputTab
                width: parent.width
                spacing: 0
                // Своё условие вместо visible: во время жеста скрытый предок
                // погасил бы и вкладку, и высота панели схлопнулась бы.
                readonly property bool shown: UiState.soundTab === "output"
                visible: shown
                height: shown ? implicitHeight : 0

                AudioLevelRow {
                    width: parent.width
                    icon: SystemIcons.soundGlyph
                    muted: AudioService.outputMuted
                    value: AudioService.outputVolume
                    onMoved: v => AudioService.setOutputVolume(v)
                    onMuteToggled: AudioService.toggleOutputMute()
                }

                AudioDeviceButton {
                    width: parent.width
                    icon: "\uf028"
                    text: AudioService.outputName
                    onClicked: UiState.openDetail("sound-output")
                }

                PanelSection { text: I18n.tr("quick.sound.applications") }

                Text {
                    width: parent.width
                    // Высоту считаем от своего условия, а не от visible:
                    // visible гаснет и вместе со скрытым предком (вид уезжает
                    // в жесте), и высота панели схлопнулась бы на движении.
                    readonly property bool shown: AudioService.streams.length === 0
                    visible: shown
                    height: shown ? Theme.touchTarget : 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: I18n.tr("quick.sound.noApps")
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }

                Repeater {
                    model: AudioService.streams

                    delegate: AudioStreamRow {
                        required property var modelData

                        width: outputTab.width
                        node: modelData
                    }
                }
            }

            // --- микрофон ----------------------------------------------
            Column {
                id: inputTab
                width: parent.width
                spacing: 0
                readonly property bool shown: UiState.soundTab === "input"
                visible: shown
                height: shown ? implicitHeight : 0

                AudioLevelRow {
                    width: parent.width
                    icon: "\uf130"
                    muted: AudioService.inputMuted
                    value: AudioService.inputVolume
                    onMoved: v => AudioService.setInputVolume(v)
                    onMuteToggled: AudioService.toggleInputMute()
                }

                AudioDeviceButton {
                    width: parent.width
                    icon: "\uf130"
                    text: AudioService.inputName
                    onClicked: UiState.openDetail("sound-input")
                }
            }
        }
    }
}
