import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Панель «Звук»: две вкладки — «Speakers» (вывод) и «Microphone» (вход).
// На вкладке вывода ещё и громкость каждого приложения: потоки
// воспроизведения играют в вывод, к микрофону они не относятся.
// Данные и действия — в AudioService; здесь только отображение.
//
// Expressive: громкость — крупный герой-блок с орбом и волнистым слайдером
// primary-акцента, устройство — залитая пилюля, потоки сгруппированы формой.
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
            title: "Sound"
            // Тумблер в шапке — mute вывода: отдельного «выключить звук
            // целиком» у PipeWire нет. Без backend переключать нечего.
            checked: !AudioService.outputMuted
            switchable: AudioService.available
            onBackRequested: root.backRequested()
            onToggled: AudioService.toggleOutputMute()
        }

        PanelDisabled {
            width: parent.width
            readonly property bool shown: !AudioService.available
            visible: shown
            height: shown ? implicitHeight : 0
            icon: "\uf028"
            title: "Audio unavailable"
            description: "PipeWire is not running"
            actionText: ""
            // Действия, которое можно предложить, нет — кнопку не рисуем.
            showAction: false
        }

        Column {
            id: availableContent
            width: parent.width
            spacing: Theme.space.xs
            readonly property bool shown: AudioService.available
            visible: shown
            height: shown ? implicitHeight : 0

            PanelTabs {
                width: parent.width
                tabs: [
                    { key: "output", title: "Speakers" },
                    { key: "input", title: "Microphone" }
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
                spacing: Theme.space.xs
                // Своё условие вместо visible: во время жеста скрытый предок
                // погасил бы и вкладку, и высота панели схлопнулась бы.
                readonly property bool shown: UiState.soundTab === "output"
                visible: shown
                height: shown ? implicitHeight : 0

                AudioLevelRow {
                    width: parent.width
                    icon: "\uf028"
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

                Item {
                    width: parent.width
                    height: 40

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.xs
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.space.xs
                        text: "Applications"
                        color: Theme.primary
                        font: Theme.typeEmphasizedTitleMedium
                    }
                }

                // Пустой список приложений — не строка, а форма и подпись.
                Item {
                    width: parent.width
                    // Высоту считаем от своего условия, а не от visible:
                    // visible гаснет и вместе со скрытым предком (вид уезжает
                    // в жесте), и высота панели схлопнулась бы на движении.
                    readonly property bool shown: AudioService.streams.length === 0
                    visible: shown
                    height: shown ? 64 : 0

                    MorphShape {
                        id: emptyBlob
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.lg
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        shape: "blob"
                        color: Theme.withAlpha(Theme.primary, 0.16)
                        modulation: 1
                    }

                    Text {
                        anchors.left: emptyBlob.right
                        anchors.leftMargin: Theme.space.md
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.lg
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: "No applications are playing audio"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }
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
                spacing: Theme.space.xs
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
