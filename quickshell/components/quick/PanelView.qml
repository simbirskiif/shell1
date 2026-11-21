import QtQuick
import ".."
import "../../singletons"

// Единая обёртка вида (основная сетка плиток и дочерние панели).
// Переход — m3 fade through: уходящий вид быстро гаснет, приходящий
// проявляется с задержкой из 92% и дорастает. Прозрачность в программном
// переходе ведёт отдельное свойство fade, поэтому виды больше не висят
// одновременно на полной яркости и заголовки не накладываются.
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

    // Непрозрачность программного перехода. Отдельно от reveal: у M3
    // fade through уходящий вид гаснет за ~120 мс, а приходящий начинает
    // проявляться только после ~90 мс. Раскрытие при этом продолжает
    // анимироваться (масштаб), и кадра «пусто» не возникает.
    property real fade: 0

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

    // Во время жеста прозрачность ведёт палец, в остальное время —
    // отдельная анимация fade (см. ниже).
    opacity: root.gestureDriven ? root.eased : root.fade
    scale: Theme.motionFadeThroughScale + (1 - Theme.motionFadeThroughScale) * root.eased
    // Активный вид держим видимым даже на нулевой прозрачности: иначе
    // ListView внутри него не создаёт делегаты и до конца перехода отдаёт
    // неполную высоту — карточка схлопывается и раздувается.
    visible: root.active || root.opacity > 0.002

    // За пальцем вид едет лишь частично: остальное делают прозрачность и
    // масштаб. Иначе на половине жеста оба вида стоят за краями панели.
    // Уходящий уезжает в сторону жеста, приходящий въезжает с обратной.
    readonly property real gestureX: {
        if (!root.gestureDriven)
            return 0;
        const share = root.gestureShift > 0 ? -(1 - root.gesture) : root.gesture;
        return root.gestureDirection * share * root.width * Theme.gestureParallax;
    }

    // Смещение задаём трансформацией: anchors и x конфликтуют,
    // а transform — нет.
    transform: Translate { x: root.gestureX }

    // Во время жеста раскрытие и прозрачность мгновенно равны целевому:
    // анимация перехода не должна догонять палец, иначе на отпускании
    // будет скачок.
    function snapReveal() {
        root.reveal = root.active ? 1 : 0;
        root.fade = root.active ? 1 : 0;
    }

    // Достаточно один раз на входе в жест: дальше раскрытием рулит палец,
    // а «мигать» при смене panel успевает onActiveChanged. На выходе из
    // жеста синхронизируем fade с состоянием вида, чтобы не было прыжка
    // с «пальцевой» прозрачности на программную.
    onGestureDrivenChanged: {
        if (root.gestureDriven) {
            root.snapReveal();
            return;
        }
        // Отпустили палец: прозрачность продолжаем с того места, где он
        // остановился, и доводим вид до целевого состояния. Иначе был бы
        // скачок с «пальцевой» прозрачности на программную.
        root.fade = root.eased;
        if (root.active) {
            appear.restart();
            fadeIn.restart();
        } else {
            disappear.restart();
            fadeOut.restart();
        }
    }

    onActiveChanged: {
        if (root.gestureDriven) {
            root.snapReveal();
            return;
        }
        if (root.active) {
            appear.restart();
            fadeIn.restart();
        } else {
            disappear.restart();
            fadeOut.restart();
        }
    }

    Component.onCompleted: {
        root.reveal = root.active ? 1 : 0;
        root.fade = root.active ? 1 : 0;
    }

    // Раскрытие (масштаб) живёт дольше прозрачности — это и даёт m3
    // fade through: контент доезжает уже без наложения соседнего вида.
    MotionNumber {
        id: appear
        target: root
        property: "reveal"
        to: 1
        duration: Theme.motionMedium2
        curve: Theme.curveEmphasizedDecelerate
    }

    MotionNumber {
        id: disappear
        target: root
        property: "reveal"
        to: 0
        duration: Theme.motionMedium2
        curve: Theme.curveEmphasizedAccelerate
    }

    // Уходящий гаснет быстро (m3: exit — первая часть перехода).
    NumberAnimation {
        id: fadeOut
        target: root
        property: "fade"
        to: 0
        duration: 120
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveStandardAccelerate
    }

    // Приходящий проявляется с задержкой 100 мс и доезжает к концу
    // перехода. Уходящий к этому моменту уже погас, поэтому заголовки
    // двух видов не накладываются, а фон карточки не пустует.
    SequentialAnimation {
        id: fadeIn

        PauseAnimation { duration: 100 }
        NumberAnimation {
            target: root
            property: "fade"
            to: 1
            duration: Theme.motionMedium2 - 100
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEmphasizedDecelerate
        }
    }

    Item {
        id: host
        anchors.fill: parent
    }
}
