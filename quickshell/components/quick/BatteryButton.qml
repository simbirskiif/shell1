import QtQuick
import ".."
import "../../singletons"

// Батарея в стиле Android: обведённая пилюля с процентом внутри,
// носик справа, цвет по состоянию (зарядка/низкий заряд), при зарядке —
// молния. Нажатие открывает панель питания.
Item {
    id: root

    required property int level
    required property bool charging

    signal clicked()

    readonly property bool low: root.level <= 15
    readonly property bool medium: !root.low && root.level <= 30

    readonly property color lineColor: {
        if (root.charging)
            return Theme.chargeColor;
        if (root.low)
            return Theme.lowColor;
        if (root.medium)
            return Theme.mediumColor;
        return Theme.quickTextDim;
    }

    readonly property color fillColor: {
        if (root.charging)
            return Theme.chargeColor;
        if (root.low)
            return Theme.lowColor;
        if (root.medium)
            return Theme.mediumColor;
        return "transparent";
    }

    readonly property color textColor: {
        if (root.charging || root.medium)
            return Theme.quickIconOn;
        if (root.low)
            return "#ffffff";
        return Theme.quickText;
    }

    implicitWidth: indicator.width + 10
    implicitHeight: indicator.height + 10

    Item {
        id: indicator
        anchors.centerIn: parent
        width: body.width + 2 + nub.width
        height: body.height

        Rectangle {
            id: body
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: content.implicitWidth + 22
            height: 26
            radius: 8
            color: root.fillColor
            border.width: 2
            border.color: root.lineColor
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            Behavior on border.color { ColorAnimation { duration: Theme.motionShort4 } }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.level + "%"
                    color: root.textColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.charging
                    text: "\uf0e7"
                    color: root.textColor
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 11
                }
            }
        }

        // Носик батареи
        Rectangle {
            id: nub
            anchors.left: body.right
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 10
            radius: 1.5
            color: root.lineColor
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hover.hovered ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
