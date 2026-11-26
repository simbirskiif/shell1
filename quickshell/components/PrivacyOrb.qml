import QtQuick
import "expressive"
import "../singletons"

// Expressive-орб индикатора конфиденциальности: форма-«печенье» с иконкой.
// У каждого устройства свой цвет, поэтому активные индикаторы в баре
// читаются и по форме, и по цвету. В панели тот же орб показывает
// неактивное состояние спокойным squircle.
Item {
    id: root

    required property string icon

    property color accent: Theme.primary
    property color onAccent: Theme.scheme.onPrimary
    property color idleAccent: Theme.surfaceContainerHighest
    property color idleOnAccent: Theme.scheme.onSurfaceVariant

    // Устройство используется. У неактивного орба форма и цвет спокойные.
    property bool active: true
    // В баре неактивные орбы сжимаются и гаснут, чтобы появление было
    // пружинным; в панели они видны всегда.
    property bool animated: true
    property bool interactive: true

    property int visualSize: 36
    property int hitSize: 40

    signal clicked()

    implicitWidth: root.hitSize
    implicitHeight: root.hitSize

    readonly property bool hovered: root.interactive && mouse.containsMouse
    readonly property bool pressed: root.interactive && mouse.pressed

    scale: (root.pressed ? 0.88 : root.hovered ? 1.06 : 1)
           * (root.animated && !root.active ? 0.35 : 1)
    opacity: root.animated && !root.active ? 0 : 1
    Behavior on scale { SpringSpatial {} }
    Behavior on opacity { SpringEffects {} }

    MorphShape {
        anchors.centerIn: parent
        width: root.visualSize
        height: root.visualSize
        keepRound: true
        shape: root.active ? (root.hovered ? "squircle" : "cookie") : "squircle"
        color: root.active ? root.accent : root.idleAccent
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.active ? root.onAccent : root.idleOnAccent
        font.family: Theme.iconFontFamily
        font.pixelSize: root.visualSize >= 44 ? Theme.iconSize.md : Theme.iconSize.sm
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
