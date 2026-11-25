import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../../singletons"

// Единое окно настроек оболочки.
//
// Это отдельная поверхность поверх всех окон, а не экран внутри быстрых
// настроек и не содержимое дока. Слева — разделы, справа — содержимое
// выбранного раздела; состояние выбора живёт в SettingsWindowState.
PanelWindow {
    id: root

    required property ShellScreen settingsScreen

    readonly property string screenName: root.settingsScreen ? root.settingsScreen.name : ""
    readonly property bool requested: SettingsWindowState.opened
                                   && SettingsWindowState.screenName === root.screenName

    // Плавное закрытие: окно остаётся видимым, пока карточка не уедет.
    property bool shown: false
    property bool closing: false

    screen: settingsScreen
    visible: root.shown || root.closing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive
                                              : WlrKeyboardFocus.None
    WlrLayershell.focusable: root.visible

    function appear() {
        closeTimer.stop();
        root.closing = false;
        root.shown = true;
    }

    function disappear() {
        if (!root.shown && !root.closing)
            return;
        root.shown = false;
        root.closing = true;
        closeTimer.restart();
    }

    function sync() {
        if (root.requested)
            root.appear();
        else
            root.disappear();
    }

    Component.onCompleted: root.sync()

    Connections {
        target: SettingsWindowState

        function onOpenedChanged() {
            root.sync();
        }

        function onScreenNameChanged() {
            root.sync();
        }

        function onSectionChanged() {
            pageScroll.contentY = 0;
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.motionMedium1
        repeat: false
        onTriggered: {
            root.closing = false;
            root.shown = false;
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: SettingsWindowState.close()
    }

    // Затемнение и закрытие по клику мимо карточки.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrimOverlay
        opacity: root.shown && !root.closing ? 1 : 0
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveStandard
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: SettingsWindowState.close()
        }
    }

    // Карточка окна: M3 surface-container-low, радиус xl, тонкая обводка.
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.max(360, Math.min(940, parent.width - Theme.space.xxxl * 2))
        height: Math.max(320, Math.min(680, parent.height - Theme.space.xxxl * 2))
        radius: Theme.shape.xl
        color: Theme.surfaceContainerLow
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true
        opacity: root.shown && !root.closing ? 1 : 0
        scale: root.shown && !root.closing ? 1 : Theme.motionFadeThroughScale
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionMedium2
                curve: Theme.curveEmphasizedDecelerate
            }
        }
        Behavior on scale {
            MotionNumber {
                duration: Theme.motionMedium2
                curve: Theme.curveEmphasizedDecelerate
            }
        }

        // Клики по самой карточке не должны доходить до подложки.
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 72

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xl
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Настройки"
                    color: Theme.scheme.onSurface
                    font: Theme.typeTitleLarge
                }

                Text {
                    text: "Изменения сохраняются автоматически"
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodySmall
                }
            }

            Item {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shape.full
                    color: closeHover.containsMouse
                           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: Theme.scheme.onSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSize.lg
                }

                MouseArea {
                    id: closeHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsWindowState.close()
                }
            }
        }

        Rectangle {
            id: headerDivider

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.outlineVariant
        }

        Rectangle {
            id: nav

            anchors.top: headerDivider.bottom
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: Math.min(248, card.width * 0.32)
            color: Theme.surfaceContainer
            // clip у карточки прямоугольный: левая колонка — единственный
            // непрозрачный слой у нижнего края, поэтому её нижний левый угол
            // скругляем сами, иначе он закрывает скругление карточки.
            bottomLeftRadius: Theme.shape.xl

            Column {
                id: navColumn

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.space.sm
                spacing: 2

                Repeater {
                    model: SettingsWindowState.sections

                    delegate: Item {
                        required property var modelData

                        readonly property bool selected:
                            SettingsWindowState.section === modelData.key

                        width: navColumn.width
                        height: Theme.touchTarget

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.shape.full
                            color: parent.selected ? Theme.secondaryContainer
                                 : (navHover.containsMouse
                                    ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                                    : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                        }

                        Text {
                            id: navIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.space.lg
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            color: selected ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurfaceVariant
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.md
                        }

                        Text {
                            anchors.left: navIcon.right
                            anchors.leftMargin: Theme.space.md
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.space.md
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title
                            color: selected ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface
                            font: Theme.typeLabelLarge
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: navHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsWindowState.setSection(modelData.key)
                        }
                    }
                }
            }
        }

        Flickable {
            id: pageScroll

            anchors.top: headerDivider.bottom
            anchors.left: nav.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.space.xl
            contentWidth: width
            contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + Theme.space.sm : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Loader {
                id: pageLoader

                width: pageScroll.width
                sourceComponent: root.pageComponent
            }
        }

        // Обводка поверх содержимого: дочерние слои рисуются выше фона
        // карточки и могут перекрывать её рамку (у левой колонки — ещё и
        // нижнее скругление).
        Rectangle {
            anchors.fill: parent
            radius: Theme.shape.xl
            color: "transparent"
            border.width: 1
            border.color: Theme.outlineVariant
            z: 100
        }

        // Тонкий индикатор прокрутки: длинные разделы (док, виджеты) не
        // помещаются в карточку целиком.
        Item {
            id: scrollTrack

            anchors.top: headerDivider.bottom
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Theme.space.sm
            visible: pageScroll.contentHeight > pageScroll.height

            Rectangle {
                width: 4
                radius: Theme.shape.full
                color: Theme.outline
                opacity: 0.55
                height: Math.max(24, scrollTrack.height * pageScroll.height
                                 / Math.max(1, pageScroll.contentHeight))
                y: (scrollTrack.height - height)
                   * pageScroll.contentY
                   / Math.max(1, pageScroll.contentHeight - pageScroll.height)
            }
        }
    }

    // Компоненты разделов. Держим их рядом с окном: навигация и страницы
    // меняются вместе, а сами страницы остаются обычными файлами.
    readonly property Component pageComponent:
        SettingsWindowState.section === "quick" ? quickPage :
        SettingsWindowState.section === "dock" ? dockPage :
        SettingsWindowState.section === "notifications" ? notificationsPage :
        SettingsWindowState.section === "caffeine" ? caffeinePage :
        SettingsWindowState.section === "widgets" ? widgetsPage :
        SettingsWindowState.section === "appearance" ? appearancePage :
        barPage

    Component { id: barPage; SettingsBarPage {} }
    Component { id: quickPage; SettingsQuickPanelPage {} }
    Component { id: dockPage; SettingsDockPage {} }
    Component { id: notificationsPage; SettingsNotificationsPage {} }
    Component { id: caffeinePage; SettingsCaffeinePage {} }
    Component { id: widgetsPage; SettingsWidgetsPage {} }
    Component { id: appearancePage; SettingsAppearancePage {} }
}
