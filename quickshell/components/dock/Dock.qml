import QtQuick
import ".."
import "../../singletons"

// Карточка дока. Окно под ней имеет постоянный размер и прозрачный фон,
// поэтому здесь можно свободно анимировать и размер, и положение: ни один
// кадр не требует пересоздания поверхности композитором.
//
// Компактная полоса и большая панель — два слоя одной карточки. При
// раскрытии ширина/высота едут Behavior'ами, а содержимое перетекает
// кроссфейдом. Если раскрытие вызвано у скрытого дока, DockState сначала
// доводит появление, и только потом включает expanded — панель не прыгает.
Item {
    id: root

    required property string screenName

    readonly property bool shown: DockState.shown && DockState.screenName === root.screenName
    readonly property bool expanded: root.shown && DockState.expanded

    // Содержимое панели проявляется не в первом кадре роста, а когда
    // карточка уже набрала ширину: иначе сетка приложений на миг
    // показывается в сжатой компактной ширине.
    property bool panelShown: false
    // Сетку приложений не создаём, пока док ни разу не показали: иначе
    // оболочка на старте грузила бы десятки иконок ради скрытой панели.
    property bool panelLoaded: false
    onShownChanged: if (root.shown) root.panelLoaded = true
    onExpandedChanged: {
        panelDelay.stop();
        if (root.expanded)
            panelDelay.restart();
        else
            root.panelShown = false;
    }

    Timer {
        id: panelDelay
        interval: 160
        onTriggered: root.panelShown = root.expanded
    }

    // 0..1 — насколько карточка выехала из-за нижней кромки.
    property real reveal: root.shown ? 1 : 0
    Behavior on reveal {
        MotionNumber {
            duration: Theme.motionMedium2
            curve: root.shown ? Theme.curveEmphasizedDecelerate
                              : Theme.curveEmphasizedAccelerate
        }
    }

    // Размеры считаются от содержимого, поэтому полоса подстраивается под
    // число избранных приложений, а панель ограничена экраном.
    readonly property real compactWidth: Math.round(compactRow.implicitWidth
                                                   + Theme.dockPadding * 2)
    readonly property real panelWidth: Math.max(root.compactWidth + 40,
        Math.min(Theme.dockPanelWidth,
                 root.parent ? root.parent.width - 24 : Theme.dockPanelWidth))
    readonly property real targetWidth: root.expanded ? root.panelWidth : root.compactWidth
    readonly property real targetHeight: root.expanded
        ? Math.min(Theme.dockPanelHeight,
                   root.parent ? root.parent.height - Theme.dockBottomMargin - 12
                               : Theme.dockPanelHeight)
        : Theme.dockHeight

    width: root.targetWidth
    height: root.targetHeight
    opacity: root.reveal
    scale: 0.96 + 0.04 * root.reveal
    transformOrigin: Item.Bottom
    visible: root.reveal > 0.001

    // m3 container transform: размер и радиус меняются вместе.
    Behavior on width {
        MotionNumber {
            duration: Theme.motionLong1
            curve: Theme.curveEmphasized
        }
    }

    Behavior on height {
        MotionNumber {
            duration: Theme.motionLong1
            curve: Theme.curveEmphasized
        }
    }

    property real cardRadius: root.expanded ? Theme.dockPanelRadius : Theme.dockRadius
    Behavior on cardRadius {
        MotionNumber {
            duration: Theme.motionLong1
            curve: Theme.curveEmphasized
        }
    }

    // Сдвиг вниз на высоту карточки: при reveal = 0 она целиком за кромкой.
    transform: Translate {
        y: (1 - root.reveal) * (root.height + Theme.dockBottomMargin + 20)
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cardRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder
        clip: true

        Row {
            id: compactRow
            anchors.centerIn: parent
            spacing: Theme.dockSpacing
            enabled: !root.expanded
            opacity: root.expanded ? 0 : 1
            // Уход полосы быстрее прихода: панель должна проявиться раньше,
            // чем пустое место успеет броситься в глаза.
            Behavior on opacity {
                MotionNumber {
                    duration: root.expanded ? Theme.motionShort3 : Theme.motionMedium1
                    curve: Theme.curveEmphasized
                }
            }
            scale: root.expanded ? 0.9 : 1
            Behavior on scale {
                MotionNumber {
                    duration: Theme.motionMedium1
                    curve: Theme.curveEmphasized
                }
            }

            Repeater {
                model: DockApps.favorites

                delegate: DockAppButton {
                    required property var modelData

                    entry: modelData
                    onActivated: DockState.hide()
                }
            }

            // Разделитель между приложениями и управляющей кнопкой.
            Item {
                width: 1
                height: Theme.dockButtonSize

                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 26
                    radius: 0.5
                    color: Theme.quickSeparator
                }
            }

            DockIconButton {
                size: 40
                glyphSize: 15
                icon: "\uf077"
                accented: true

                onClicked: DockState.expand(root.screenName, false)
            }
        }

        Loader {
            id: panelLoader
            anchors.fill: parent
            anchors.margins: Theme.dockPanelPadding
            active: root.panelLoaded
            sourceComponent: panelComponent
            enabled: root.panelShown
            opacity: root.panelShown ? 1 : 0
            visible: opacity > 0.001
            Behavior on opacity {
                MotionNumber {
                    duration: root.panelShown ? Theme.motionMedium1 : Theme.motionShort3
                    curve: Theme.curveEmphasized
                }
            }
        }
    }

    Component {
        id: panelComponent

        DockPanel {
            screenName: root.screenName

            onCloseRequested: DockState.hide()
            onQuickSettingsRequested: {
                DockState.hide();
                UiState.open(root.screenName, "");
            }
        }
    }
}
