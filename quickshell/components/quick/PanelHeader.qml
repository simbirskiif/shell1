import QtQuick
import ".."
import "../../singletons"

// Шапка внутренней панели в духе M3 top app bar: кнопка «назад», заголовок
// titleLarge, справа — действия-иконки и переключатель.
Item {
    id: root

    required property string title
    required property bool checked
    property bool refreshable: false
    property bool refreshing: false
    // Дополнительное действие (например, режим обнаружения).
    property string actionIcon: ""
    property bool actionChecked: false
    // У некоторых панелей (например «Питание») тумблера нет.
    property bool switchable: true
    // Показывать ли состояние Wi-Fi рядом с названием (панель «Интернет»).
    property bool wifiStatus: false

    signal backRequested()
    signal toggled()
    signal refreshRequested()
    signal actionRequested()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.appBarHeight
    height: implicitHeight

    // Кнопка «назад» — M3 icon button 40dp.
    Rectangle {
        id: backButton
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: width / 2
        color: backHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            text: "\uf053"
            color: Theme.scheme.onSurface
            font.family: Theme.iconFontFamily
            font.pixelSize: 22
        }

        MouseArea {
            id: backHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
        }
    }

    Row {
        id: titleRow
        anchors.left: backButton.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: rightGroup.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.sm

        Text {
            id: titleText
            width: Math.min(implicitWidth, titleRow.width
                            - (wifiIcon.visible ? wifiIcon.width + titleRow.spacing : 0))
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.scheme.onSurface
            font: Theme.typeEmphasizedHeadlineSmall
            elide: Text.ElideRight
        }

        // Состояние Wi-Fi в шапке панели «Интернет».
        WifiStatusIcon {
            id: wifiIcon
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            glyphSize: 15
            visible: root.wifiStatus
            offMode: !NetworkService.wifiEnabled
            signal: NetworkService.connectedSignal
            dim: !NetworkService.wifiEnabled
        }
    }

    // Правая группа: действие, обновление, переключатель.
    Row {
        id: rightGroup
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Item {
            id: actionButton
            width: root.actionIcon !== "" ? 44 : 0
            height: 44
            visible: width > 0

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.actionChecked ? Theme.secondaryContainer
                                          : (actionHover.containsMouse ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                                                                 : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            Text {
                anchors.centerIn: parent
                text: root.actionIcon
                color: root.actionChecked ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.md
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            MouseArea {
                id: actionHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionRequested()
            }
        }

        Item {
            id: refreshButton
            width: root.refreshable ? 44 : 0
            height: 44
            visible: width > 0

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: refreshHover.containsMouse && !root.refreshing
                       ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }

            // Пока идёт поиск — вместо значка обновления крутится индикатор.
            Text {
                id: refreshIcon
                anchors.centerIn: parent
                visible: !root.refreshing
                text: "\uf021"
                color: Theme.scheme.onSurface
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.md
            }

            LoadingIndicator {
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: root.refreshing
            }

            MouseArea {
                id: refreshHover
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.refreshing
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refreshRequested()
            }
        }

        ToggleSwitch {
            id: toggle
            visible: root.switchable
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            onToggled: root.toggled()
        }
    }
}
