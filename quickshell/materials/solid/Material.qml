import QtQuick

// Самый простой материал: surface + скругление. Все свойства приходят от
// WidgetHost; контракт описан в README и docs/WIDGET_AUTHORING.md.
Item {
    id: root

    property var colors: ({})
    property real radius: 0
    property var size: Qt.size(0, 0)
    property string wallpaperSource: ""
    property bool editing: false
    property real offsetX: 0
    property real offsetY: 0
    property real screenWidth: 0
    property real screenHeight: 0

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.colors.surface || "#1C1B1F"
    }

}
