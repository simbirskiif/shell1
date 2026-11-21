import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Единый экран «модуль выключен»: показывается вместо списков,
// когда Wi-Fi/Bluetooth выключены.
//
// Expressive: вместо строки-заглушки — крупная форма (cookie для иконки,
// blob-пятно за ней), заголовок typeEmphasizedTitleLarge, тело bodyMedium
// и большая кнопка-пилюля. Тонких рамок нет.
Item {
    id: root

    required property string icon
    // Своя иконка вместо глифа (например индикатор Wi-Fi с делениями).
    property bool wifiIcon: false
    required property string title
    required property string description
    required property string actionText
    // Кнопка скрывается, когда действие невозможно: например, Wi-Fi
    // заблокирован аппаратным переключателем и включить его нельзя.
    property bool showAction: true

    signal actionRequested()

    readonly property bool actionHovered: actionHover.containsMouse
    readonly property bool actionPressed: actionHover.pressed

    implicitWidth: Theme.quickWidth
    implicitHeight: 264

    // Фоновое пятно: группирует заглушку формой, а не рамкой.
    MorphShape {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Theme.space.xl
        width: 210
        height: 210
        shape: "blob"
        color: Theme.withAlpha(Theme.tertiaryContainer, 0.4)
        modulation: 0.55
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Theme.space.xxxl - Theme.space.sm
        spacing: Theme.space.sm

        // Крупный орб-«печенье» с иконкой: состояние читается формой.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 92
            height: 92

            MorphShape {
                anchors.fill: parent
                shape: "cookie"
                color: Theme.secondaryContainer
                modulation: 0.7
            }

            Text {
                anchors.centerIn: parent
                visible: !root.wifiIcon
                text: root.icon
                color: Theme.scheme.onSecondaryContainer
                font.family: Theme.iconFontFamily
                font.pixelSize: 38
            }

            WifiStatusIcon {
                anchors.centerIn: parent
                visible: root.wifiIcon
                width: 54
                height: 54
                glyphSize: 34
                offMode: true
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            color: Theme.scheme.onSurface
            font: Theme.typeEmphasizedTitleLarge
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.description
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }

        Item {
            width: 1
            height: root.showAction ? Theme.space.sm : 0
        }

        // Кнопка Expressive: крупная пилюля primary, hover меняет форму на
        // squircle, нажатие пружинно сжимает.
        Item {
            id: button
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.showAction ? buttonLabel.implicitWidth + Theme.space.xxl : 0
            height: root.showAction ? 48 : 0
            visible: root.showAction
            scale: root.actionPressed ? 0.94 : (root.actionHovered ? 1.03 : 1)

            Behavior on scale { SpringSpatialFast {} }

            MorphShape {
                anchors.fill: parent
                shape: root.actionHovered ? "squircle" : "pill"
                color: Theme.primary
                modulation: 0.4
            }

            Text {
                id: buttonLabel
                anchors.centerIn: parent
                text: root.actionText
                color: Theme.scheme.onPrimary
                font: Theme.typeEmphasizedLabelLarge
            }

            MouseArea {
                id: actionHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionRequested()
            }
        }
    }
}
