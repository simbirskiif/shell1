import QtQuick
import QtQuick.Effects
import Quickshell
import ".."
import "../../singletons"
import "../../widgets/core"

// Содержимое экрана блокировки: размытые обои, часы, аватар, поле пароля
// и кнопка отпечатка. Одна и та же разметка создаётся на каждый экран
// в LockSession.
//
// Компонент — обычный Item (не WlSessionLockSurface): его можно показать
// в отдельном окне для проверки разметки, не блокируя сессию.
Item {
    id: root

    // Масштаб от высоты экрана: на 1080p элементы базового размера, на
    // 1600p крупнее, на 768p мельче, но не настолько, чтобы поле ввода
    // теряло читаемость.
    readonly property real scale: Math.max(0.82, Math.min(1.30, root.height / 1080))
    readonly property int fieldWidth: Math.round(340 * root.scale)
    readonly property int fieldHeight: Math.round(54 * root.scale)
    readonly property int fingerprintSize: Math.round(54 * root.scale)
    readonly property int contentWidth: root.fieldWidth + root.fingerprintSize
                                        + Math.round(10 * root.scale)

    // Смещение для тряски при неверном пароле.
    property real shakeOffset: 0
    // Анимация входа: 0 — контент скрыт, 1 — показан.
    property real intro: 0

    // ── фон ────────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.surface }
            GradientStop { position: 1.0; color: Theme.mix(Theme.surface, Wal.accent, 0.10) }
        }
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: Wallpaper.sourceUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        // hyprlock размывает всё полотно целиком; blurMax ограничен, чтобы
        // не жечь GPU на 4K.
        blurEnabled: true
        blur: 0.9
        blurMax: 64
        saturation: -0.10
        brightness: -0.05
        // visible всегда true: если эффект создан невидимым (обои ещё не
        // прочитаны), при появлении изображения он может не пересобрать
        // текстуру и показать обои без размытия.
        visible: true
    }

    // Затемнение и тональная подложка поверх размытых обоев.
    // surface-dim — роль M3 именно для приглушения (в светлой схеме она
    // светлее базовой, в тёмной — темнее), поэтому текст on-surface
    // сохраняет контраст на любых обоях.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.veil(Theme.surfaceDim, 0.55) }
            GradientStop { position: 0.45; color: Theme.veil(Theme.surfaceDim, 0.38) }
            GradientStop { position: 1.0; color: Theme.veil(Theme.surfaceDim, 0.62) }
        }
    }

    // Сама подложка — surface-container-high с низкой альфой: тот же приём,
    // что у панелей оболочки, только полупрозрачнее.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.veil(Theme.surfaceContainerHigh, 0.55) }
            GradientStop { position: 0.45; color: Theme.veil(Theme.surfaceContainerHigh, 0.42) }
            GradientStop { position: 1.0; color: Theme.veil(Theme.surfaceContainerHigh, 0.62) }
        }
    }

    // Клик по пустому месту возвращает фокус полю, чтобы не «потерять» ввод.
    MouseArea {
        anchors.fill: parent
        onClicked: passwordInput.forceActiveFocus()
    }

    // ── контент ────────────────────────────────────────────────────────

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item {
        id: content

        anchors.centerIn: parent
        width: root.contentWidth
        height: column.height
        opacity: LockState.unlocking ? 0 : 1
        scale: LockState.unlocking ? 1.04 : 1

        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionMedium2
                curve: Theme.curveEmphasizedAccelerate
            }
        }
        Behavior on scale {
            MotionNumber {
                duration: Theme.motionMedium2
                curve: Theme.curveEmphasizedDecelerate
            }
        }

        Column {
            id: column

            width: parent.width
            opacity: root.intro

            // Часы — displayLarge: самый крупный уровень шкалы M3, он же
            // герой-текст экрана блокировки.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: clock.date.toLocaleTimeString(Qt.locale(I18n.locale), "HH:mm")
                color: Theme.scheme.onSurface
                font: Theme.typeDisplayLarge
            }

            // Дата — titleLarge: следующий по иерархии уровень.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: Math.round(2 * root.scale)
                text: clock.date.toLocaleDateString(Qt.locale(I18n.locale), "dddd, d MMMM")
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeTitleLarge
            }

            Item { width: 1; height: Math.round(46 * root.scale) }

            // Аватар: инициал пользователя. ~/.face может не быть, а
            // AccountsService в Wayland-сессии не гарантирован.
            Item {
                width: parent.width
                height: Math.round(76 * root.scale)

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(76 * root.scale)
                    height: width
                    radius: width / 2
                    color: Theme.veil(Theme.surfaceContainerHighest, 0.55)
                    border.width: 1
                    border.color: Theme.outlineVariant

                    Text {
                        anchors.centerIn: parent
                        text: LockState.avatarLetter
                        color: Theme.scheme.onSurface
                        font: Theme.typeHeadlineLarge
                    }
                }
            }

            Item { width: 1; height: Math.round(18 * root.scale) }

            Item {
                width: parent.width
                height: root.fieldHeight

                // Карточка входа: тональная surface-container-high с низкой
                // альфой и радиусом shape.xl — поле и сканер читаются как
                // одна поверхность M3.
                Rectangle {
                    anchors.fill: inputRow
                    anchors.margins: -Theme.space.sm
                    radius: Theme.shape.xl
                    color: Theme.veil(Theme.surfaceContainerHigh, 0.55)
                }

                Row {
                    id: inputRow

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * root.scale)
                    transform: Translate { x: root.shakeOffset }

                    // Поле пароля — заполненное поле M3: контейнер
                    // surface-container-highest, радиус shape.xs, обводка
                    // outline, в фокусе — primary толщиной 2.
                    Rectangle {
                        id: field

                        width: root.fieldWidth
                        height: root.fieldHeight
                        radius: Theme.shape.xs
                        color: Theme.veil(Theme.surfaceContainerHighest, 0.92)
                        border.width: passwordInput.activeFocus
                                      ? Math.max(1, Math.round(2 * root.scale)) : 1
                        border.color: passwordInput.activeFocus
                                      ? Theme.primary : Theme.outline

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.motionShort3 }
                        }

                        Text {
                            id: lockIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(18 * root.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf023"
                            color: passwordInput.activeFocus
                                   ? Theme.primary : Theme.scheme.onSurfaceVariant
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.lg

                            Behavior on color {
                                ColorAnimation { duration: Theme.motionShort3 }
                            }
                        }

                        TextInput {
                            id: passwordInput

                            anchors.left: lockIcon.right
                            anchors.leftMargin: Math.round(11 * root.scale)
                            anchors.right: parent.right
                            anchors.rightMargin: Math.round(18 * root.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            passwordMaskDelay: 0
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.scheme.onPrimary
                            color: Theme.scheme.onSurface
                            font: Theme.typeBodyLarge
                            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                              | Qt.ImhNoAutoUppercase
                            enabled: !LockState.authenticating && !LockState.unlocking
                            activeFocusOnPress: true

                            onAccepted: root.submit()

                            Keys.onEscapePressed: (event) => {
                                passwordInput.text = "";
                                event.accepted = true;
                            }

                            // Caps Lock — модификатор без события состояния:
                            // чтобы индикатор не врал, отслеживаем нажатие.
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_CapsLock)
                                    LockState.toggleCapsLock();
                            }
                        }

                        Text {
                            anchors.left: passwordInput.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: passwordInput.text.length === 0
                            text: I18n.tr("lock.enterPassword")
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodyLarge
                        }
                    }

                    // Кнопка сканера — иконка-кнопка M3: контейнер
                    // surface-container-highest, при сканировании —
                    // обводка primary толщиной 2 и пульсация, чтобы было
                    // видно, что сканер «слушает».
                    Rectangle {
                        id: fingerprintButton

                        visible: LockState.fingerprintState !== "unavailable"
                        width: root.fingerprintSize
                        height: root.fingerprintSize
                        radius: Theme.shape.full
                        color: fingerprintHover.containsMouse
                               ? Theme.surfaceContainerHigh
                               : Theme.veil(Theme.surfaceContainerHighest, 0.92)
                        border.width: LockState.fingerprintState === "scanning" ? 2 : 1
                        border.color: LockState.fingerprintState === "scanning"
                                      ? Theme.primary : Theme.outline

                        Behavior on color {
                            ColorAnimation { duration: Theme.motionShort3 }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: Theme.motionShort3 }
                        }

                        Text {
                            id: fingerprintIcon

                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF0237)
                            color: LockState.fingerprintState === "scanning"
                                   ? Theme.primary
                                   : Theme.withAlpha(Theme.scheme.onSurface,
                                                     LockState.fingerprintState === "checking"
                                                     ? Theme.disabledContent : 0.85)
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.lg

                            SequentialAnimation {
                                id: fingerprintPulse

                                running: LockState.fingerprintState === "scanning"
                                loops: Animation.Infinite
                                onStopped: fingerprintIcon.opacity = 1

                                NumberAnimation {
                                    target: fingerprintIcon
                                    property: "opacity"
                                    to: 0.45
                                    duration: 700
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: fingerprintIcon
                                    property: "opacity"
                                    to: 1.0
                                    duration: 700
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        MouseArea {
                            id: fingerprintHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LockState.requestFingerprint()
                        }
                    }
                }
            }

            Item { width: 1; height: Math.round(14 * root.scale) }

            // Строка статуса: ошибка — тональная плашка error-container
            // с текстом on-error-container, остальные состояния — нейтральная
            // полупрозрачная подложка.
            Rectangle {
                width: parent.width
                height: statusLine.implicitHeight + Theme.space.sm * 2
                visible: root.statusText !== ""
                radius: Theme.shape.xs
                color: root.statusPlateColor

                Behavior on color {
                    ColorAnimation { duration: Theme.motionShort3 }
                }

                Text {
                    id: statusLine

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space.md
                    anchors.rightMargin: Theme.space.md
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.statusText
                    color: root.statusColor
                    font: Theme.typeBodyMedium

                    Behavior on color {
                        ColorAnimation { duration: Theme.motionShort3 }
                    }
                }
            }
        }
    }

    // ── производные состояния ──────────────────────────────────────────

    readonly property string statusText: {
        if (LockState.unlocking)
            return "";
        if (LockState.statusKind === "error")
            return LockState.statusText;
        if (LockState.authenticating)
            return LockState.statusText;
        if (LockState.capsLock)
            return I18n.tr("lock.capsLock");
        switch (LockState.fingerprintState) {
        case "scanning":
            return I18n.tr("lock.fingerprint.touch");
        case "retry":
            return I18n.tr("lock.fingerprint.retry");
        case "busy":
            return I18n.tr("lock.fingerprint.busy");
        case "error":
            return LockState.fingerprintHint !== "" ? LockState.fingerprintHint
                                                   : I18n.tr("lock.fingerprint.unavailable");
        case "unavailable":
            return "";
        }
        return "";
    }

    readonly property color statusColor: {
        if (LockState.statusKind === "error")
            return Theme.scheme.onErrorContainer;
        if (LockState.fingerprintState === "retry" || LockState.fingerprintState === "busy")
            return Theme.warningColor;
        if (LockState.authenticating)
            return Theme.scheme.onSurfaceVariant;
        if (LockState.capsLock)
            return Theme.warningColor;
        return Theme.scheme.onSurfaceVariant;
    }

    // Подложка строки статуса: ошибка — error-container, прочее — та же
    // surface-container-highest, что у поля, но с низкой альфой.
    readonly property color statusPlateColor: {
        if (LockState.statusKind === "error")
            return Theme.errorContainer;
        return Theme.veil(Theme.surfaceContainerHighest, 0.55);
    }

    function submit() {
        if (passwordInput.text.length === 0)
            return;
        const value = passwordInput.text;
        if (!LockState.submitPassword(value))
            return;
        // Пароль ушёл в PAM: в поле ему больше нечего делать.
        passwordInput.text = "";
    }

    // Неверный пароль: поле очищаем и коротко трясём — так ошибка видна,
    // даже если строка статуса вне фокуса внимания.
    Connections {
        target: LockState

        function onFailedAttemptsChanged() {
            if (LockState.failedAttempts === 0)
                return;
            passwordInput.text = "";
            shake.restart();
            passwordInput.forceActiveFocus();
        }

        function onUnlockingChanged() {
            if (LockState.unlocking)
                passwordInput.text = "";
        }
    }

    SequentialAnimation {
        id: shake

        NumberAnimation { target: root; property: "shakeOffset"; to: -Math.round(7 * root.scale); duration: 55 }
        NumberAnimation { target: root; property: "shakeOffset"; to: Math.round(7 * root.scale); duration: 70 }
        NumberAnimation { target: root; property: "shakeOffset"; to: -Math.round(5 * root.scale); duration: 65 }
        NumberAnimation { target: root; property: "shakeOffset"; to: Math.round(4 * root.scale); duration: 60 }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 70 }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
        introAnimation.start();
    }

    NumberAnimation {
        id: introAnimation

        target: root
        property: "intro"
        from: 0
        to: 1
        duration: Theme.motionLong1
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveEmphasizedDecelerate
    }
}
