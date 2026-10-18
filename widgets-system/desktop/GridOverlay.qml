import QtQuick

// Отладочная отрисовка сетки (этап 1).
// Не принимает ввод: мышь и касания должны проходить сквозь слой,
// поэтому здесь нет ни одного MouseArea. Маска ввода задаётся в DesktopLayer.
Item {
    id: root

    required property var metrics

    readonly property real gridX: root.metrics.originX
    readonly property real gridY: root.metrics.originY
    readonly property real gridW: root.metrics.gridW
    readonly property real gridH: root.metrics.gridH

    enabled: false

    // Фон рабочей области: чуть темнее обоев, чтобы границы клеток читались.
    Rectangle {
        x: root.gridX
        y: root.gridY
        width: root.gridW
        height: root.gridH
        color: "#4D000000"
        border.width: 1
        border.color: "#88FFFFFF"
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
            color: "#80FFFFFF"
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
            color: "#80FFFFFF"
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
            color: "#CCFFFFFF"
        }
    }

    // Плашка с параметрами: используется при приёмке этапа 1.
    Rectangle {
        id: info

        x: root.gridX + 12
        y: root.gridY + 12
        width: infoText.implicitWidth + 24
        height: infoText.implicitHeight + 16
        radius: 8
        color: "#CC101014"
        border.width: 1
        border.color: "#33FFFFFF"

        Text {
            id: infoText

            anchors.centerIn: parent
            color: "#E6E1E5"
            font.family: "monospace"
            font.pixelSize: 12
            text: root.metrics.screenName
                  + "  •  " + root.metrics.cols + " × " + root.metrics.rows + " клеток"
                  + "  •  клетка " + Math.round(root.metrics.cell) + " px = "
                  + root.metrics.cellMm.toFixed(1) + " мм"
                  + "  •  dpr " + root.metrics.dpr.toFixed(2)
                  + "  •  dp " + root.metrics.dp.toFixed(2)
        }
    }
}
