import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Вкладки панели в Expressive-варианте: не подчёркивание, а склеенная
// группа кнопок. Активный сегмент шире и залит tertiary-container,
// при нажатии группа деформируется (см. SegmentedButtonGroup).
// Компонент «глупый»: список вкладок [{ key, title }] и текущий ключ
// приходят снаружи, наружу уходит выбранный ключ.
Item {
    id: root

    required property var tabs
    required property string current

    signal selected(string key)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 56
    height: implicitHeight

    SegmentedButtonGroup {
        anchors.fill: parent
        anchors.leftMargin: Theme.space.sm
        anchors.rightMargin: Theme.space.sm
        tabs: root.tabs
        current: root.current
        tone: "tertiary"
        onSelected: key => root.selected(key)
    }
}
