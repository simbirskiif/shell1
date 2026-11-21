import QtQuick
import ".."
import "../../singletons"

// Индикатор загрузки в духе m3 circular progress: дуга вращается и
// попеременно растягивается/сжимается.
Item {
    id: root

    implicitWidth: Theme.iconSize.md
    implicitHeight: Theme.iconSize.md

    property real sweep: 90

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            // Дуга индикатора — primary, как у m3 circular progress.
            ctx.strokeStyle = Theme.primary;
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.beginPath();
            const radius = Math.min(width, height) / 2 - 2;
            ctx.arc(width / 2, height / 2, radius, 0, root.sweep * Math.PI / 180);
            ctx.stroke();
        }

        Connections {
            target: root

            function onSweepChanged() {
                canvas.requestPaint();
            }
        }

        Connections {
            target: Theme

            // Индикатор перерисовывается при смене акцентной роли схемы.
            function onPrimaryChanged() {
                canvas.requestPaint();
            }
        }
    }

    NumberAnimation on rotation {
        from: 0
        to: 360
        duration: 1300
        loops: Animation.Infinite
        running: true
    }

    SequentialAnimation on sweep {
        loops: Animation.Infinite
        running: true
        MotionNumber {
            to: 280
            duration: 650
            curve: Theme.curveEmphasized
        }
        MotionNumber {
            to: 90
            duration: 650
            curve: Theme.curveEmphasized
        }
    }
}
