import QtQuick
import "../../singletons"

// Отладочная отрисовка сетки (этап 1).
// Не принимает ввод: мышь и касания должны проходить сквозь слой,
// поэтому здесь нет ни одного MouseArea. Маска ввода задаётся в DesktopLayer.
//
// Оформление — по M3: сетка рисуется outline-variant с малой альфой, без
// ярких цветов, а плашка параметров — обычная tonal surface, а не «чёрный
// ящик» с ручными hex-цветами.
Item {
    id: root

    required property var metrics

    readonly property real gridX: root.metrics.originX
    readonly property real gridY: root.metrics.originY
    readonly property real gridW: root.metrics.gridW
    readonly property real gridH: root.metrics.gridH

    enabled: false

    // Фон рабочей области: затемнение обоев scrim'ом, чтобы границы клеток
    // читались и при этом не спорили с тональными поверхностями виджетов.
    Rectangle {
        x: root.gridX
        y: root.gridY
        width: root.gridW
        height: root.gridH
        color: Theme.withAlpha(Theme.scrim, 0.28)
        border.width: 1
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.55)
    }

    // Вертикальные линии по границам клеток.
    Repeater {
        model: root.metrics.cols + 1

        delegate: Rectangle {
            required property int index

            x: Math.round(root.gridX + index * (root.metrics.cell + root.metrics.gap))
            y: root.gridY
            width: 1
            height: root.gridH
            // Сетка декоративная: outline-variant с малой альфой.
            color: Theme.withAlpha(Theme.outlineVariant, 0.38)
        }
    }

    // Горизонтальные линии по границам клеток.
    Repeater {
        model: root.metrics.rows + 1

        delegate: Rectangle {
            required property int index

            x: root.gridX
            y: Math.round(root.gridY + index * (root.metrics.cell + root.metrics.gap))
            width: root.gridW
            height: 1
            // Сетка декоративная: outline-variant с малой альфой.
            color: Theme.withAlpha(Theme.outlineVariant, 0.38)
        }
    }

    // Точки в центрах клеток помогают оценить размер клетки глазами.
    Repeater {
        model: root.metrics.cols * root.metrics.rows

        delegate: Rectangle {
            required property int index

            readonly property int col: index % root.metrics.cols
            readonly property int row: Math.floor(index / root.metrics.cols)

            x: Math.round(root.gridX + col * (root.metrics.cell + root.metrics.gap)
                          + root.metrics.cell / 2) - 2
            y: Math.round(root.gridY + row * (root.metrics.cell + root.metrics.gap)
                          + root.metrics.cell / 2) - 2
            width: 4
            height: 4
            radius: 2
            color: Theme.withAlpha(Theme.outlineVariant, 0.55)
        }
    }

    // Плашка с параметрами: используется при приёмке этапа 1.
    Rectangle {
        id: info

        x: root.gridX + Theme.space.md
        y: root.gridY + Theme.space.md
        width: infoText.implicitWidth + Theme.space.lg * 2
        height: infoText.implicitHeight + Theme.space.md * 2
        radius: Theme.shape.md
        color: Theme.veil(Theme.surfaceContainerHigh, 0.96)
        border.width: 1
        border.color: Theme.outlineVariant

        Text {
            id: infoText

            anchors.centerIn: parent
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelSmall
            text: root.metrics.screenName
                  + "  •  " + root.metrics.cols + " × " + root.metrics.rows + " клеток"
                  + "  •  клетка " + Math.round(root.metrics.cell) + " px = "
                  + root.metrics.cellMm.toFixed(1) + " мм"
                  + "  •  dpr " + root.metrics.dpr.toFixed(2)
                  + "  •  dp " + root.metrics.dp.toFixed(2)
        }
    }
}
