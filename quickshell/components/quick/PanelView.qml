import QtQuick
import ".."
import "../../singletons"

// Единая обёртка вида (основная сетка плиток и дочерние панели).
// Переход — m3 fade through: уходящий вид уменьшается и растворяется,
// приходящий проявляется из 92% и дорастает.
// Тем же раскрытием управляет и жест «назад»: палец и анимация пишут в одно
// свойство reveal, поэтому в момент отпускания нет ни мигания, ни рывка.
Item {
    id: root

    required property bool active

    // Жест возврата: gesture 0..1 (-1 — жест не идёт).
    property real gesture: -1
    // -1 — уходящий вид, +1 — приходящий.
    property int gestureShift: -1
    // +1 — жест вправо, -1 — влево.
    property int gestureDirection: 1

    default property alias content: host.data

    readonly property Item view: host.children.length > 0 ? host.children[0] : null

    implicitWidth: view ? view.implicitWidth : 0
    implicitHeight: view ? view.implicitHeight : 0

    // 0 — вид скрыт, 1 — показан целиком. Без жеста сюда пишет анимация
    // перехода, во время жеста — прогресс пальца (мгновенно, без анимации).
    property real reveal: 0

    readonly property bool gestureDriven: root.gesture >= 0
    // Для приходящего вида жест — это само раскрытие, для уходящего — обратное.
    readonly property real gestureReveal: root.gesture < 0 ? -1
        : (root.gestureShift > 0 ? root.gesture : 1 - root.gesture)

    readonly property real shown: root.gestureDriven ? root.gestureReveal : root.reveal

    // smoothstep: «уходящий + приходящий» остаётся постоянной, поэтому в
    // середине жеста нет кадра, где на экране не видно ни одного вида.
    readonly property real eased: {
        const t = Math.max(0, Math.min(1, root.shown));
        return t * t * (3 - 2 * t);
    }

    opacity: root.eased
    scale: Theme.motionFadeThroughScale + (1 - Theme.motionFadeThroughScale) * root.eased
    visible: root.eased > 0.002

    // За пальцем вид едет лишь частично: остальное делают прозрачность и
    // масштаб. Иначе на половине жеста оба вида стоят за краями панели.
    readonly property real gestureX: {
        if (!root.gestureDriven)
            return 0;
        const share = root.gestureShift > 0 ? (1 - root.gesture) : -root.gesture;
        return root.gestureDirection * share * root.width * Theme.gestureParallax;
    }

    // Смещение задаём трансформацией: anchors и x конфликтуют,
    // а transform — нет.
    transform: Translate { x: root.gestureX }

    // Во время жеста раскрытие мгновенно равно целевому: анимация перехода
    // не должна догонять палец, иначе на отпускании будет скачок.
    function snapReveal() {
        root.reveal = root.active ? 1 : 0;
    }

    onGestureChanged: {
        if (root.gestureDriven)
            root.snapReveal();
    }

    onActiveChanged: {
        if (root.gestureDriven) {
            root.snapReveal();
            return;
        }
        if (root.active)
            appear.restart();
        else
            disappear.restart();
    }

    Component.onCompleted: root.reveal = root.active ? 1 : 0

    // m3 fade through: уходящий гаснет первым, приходящий — в оставшиеся 70%.
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: Theme.motionMedium2 * Theme.motionFadeOutShare }
        MotionNumber {
            target: root
            property: "reveal"
            to: 1
            duration: Theme.motionMedium2 * (1 - Theme.motionFadeOutShare)
            curve: Theme.curveEmphasizedDecelerate
        }
    }

    MotionNumber {
        id: disappear
        target: root
        property: "reveal"
        to: 0
        duration: Theme.motionMedium2 * Theme.motionFadeOutShare
        curve: Theme.curveEmphasizedAccelerate
    }

    Item {
        id: host
        anchors.fill: parent
    }
}
