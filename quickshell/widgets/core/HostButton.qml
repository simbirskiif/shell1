import QtQuick
import "../../singletons"

// Маленькая кнопка для карточек, каталога и попапа настроек.
Rectangle {
    id: root

    property string text: ""
    property bool active: false
    property bool prominent: false
    signal clicked()

    implicitWidth: label.implicitWidth + (root.prominent ? 26
                                       : (root.text.length > 1 ? 18 : 12))
    implicitHeight: root.prominent ? 30 : 26
    radius: root.prominent ? 10 : 9
    // Кнопки редактора/панелей висят над произвольным фоном: подложка
    // должна быть плотной, иначе «Готово/Отмена» теряются на обоях.
    color: root.active ? Theme.menuSurface
           : (mouse.containsMouse ? Theme.menuSurfaceHover : Theme.menuSurface)
    border.width: 1
    border.color: root.active ? Theme.colors.primary : Theme.quickBorder

    Text {
        id: label

        anchors.centerIn: parent
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: root.prominent ? 12 : 11
        font.bold: root.prominent
        text: root.text
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
