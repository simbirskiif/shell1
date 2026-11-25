import QtQuick
import "../../singletons"

// Страница раздела: заголовок, короткое пояснение и колонка карточек.
// Дочерние объекты страницы попадают в contentColumn, поэтому страницы
// описываются простым списком SettingsCard.
Column {
    id: root

    property string title: ""
    property string description: ""

    default property alias content: contentColumn.data

    width: parent ? parent.width : 0
    spacing: Theme.space.lg

    Column {
        width: parent.width
        spacing: Theme.space.xs

        Text {
            width: parent.width
            text: root.title
            color: Theme.scheme.onSurface
            font: Theme.typeHeadlineSmall
        }

        Text {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
            wrapMode: Text.WordWrap
        }
    }

    Column {
        id: contentColumn

        width: parent.width
        spacing: Theme.space.lg
    }
}
