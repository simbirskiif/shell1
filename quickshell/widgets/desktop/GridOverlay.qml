pragma ComponentBehavior: Bound

import QtQuick
import "../../components/expressive"
import "../../singletons"

// Отладочная отрисовка сетки (этап 1).
// Не принимает ввод: мышь и касания должны проходить сквозь слой,
// поэтому здесь нет ни одного MouseArea. Маска ввода задаётся в DesktopLayer.
//
// Оформление — Expressive: сетка остаётся тонкой (outline-variant с малой
// альфой, чтобы не спорить с виджетами), а плашка параметров — заметный
// tertiary-контейнер-пилюля с emphasised-типографикой, как «ярлык» поверх
// рабочего стола, а не системный чёрный ящик.
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
        color: Theme.withAlpha(Theme.scrim, 0.26)
        border.width: 1
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.45)
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
            // Сетка декоративная и очень тихая: outline-variant с малой альфой.
            color: Theme.withAlpha(Theme.outlineVariant, 0.26)
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
            // Сетка декоративная и очень тихая: outline-variant с малой альфой.
            color: Theme.withAlpha(Theme.outlineVariant, 0.26)
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
            color: Theme.withAlpha(Theme.outlineVariant, 0.42)
        }
    }

    // Плашка с параметрами: выразительный контейнер, а не служебная рамка.
    // Пилюля с лёгкой волной (modulation 0.5 — читается как ярлык, но не
    // разваливает строку) и крупной подписью.
    Item {
        id: info

        x: root.gridX + Theme.space.md
        y: root.gridY + Theme.space.md
        width: infoText.implicitWidth + Theme.space.xl * 2
        height: 44

        MorphShape {
            anchors.fill: parent
            shape: "pill"
            modulation: 0.5
            color: Theme.tertiaryContainer
            borderWidth: 0
        }

        Text {
            id: infoText

            anchors.centerIn: parent
            color: Theme.scheme.onTertiaryContainer
            font: Theme.typeEmphasizedLabelLarge
            text: root.metrics.screenName
                  + "  •  " + root.metrics.cols + " × " + root.metrics.rows + " клеток"
                  + "  •  клетка " + Math.round(root.metrics.cell) + " px = "
                  + root.metrics.cellMm.toFixed(1) + " мм"
                  + "  •  dpr " + root.metrics.dpr.toFixed(2)
                  + "  •  dp " + root.metrics.dp.toFixed(2)
        }
    }
}
