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
            GradientStop { position: 0.0; color: Theme.quickBackground }
            GradientStop { position: 1.0; color: Theme.mix(Theme.quickBackground, Wal.accent, 0.10) }
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

    // Затемнение и лёгкий градиент: текст должен читаться на любых обоях.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.42) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.18) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.52) }
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

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: clock.date.toLocaleTimeString(Qt.locale(), "HH:mm")
                color: Theme.quickText
                font.family: "Google Sans Display"
                font.pixelSize: Math.round(96 * root.scale)
                font.weight: Font.Normal
                font.letterSpacing: -Math.round(2 * root.scale)
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: Math.round(2 * root.scale)
                text: clock.date.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                color: Theme.withAlpha(Theme.quickText, 0.72)
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(17 * root.scale)
                font.letterSpacing: Math.round(0.6 * root.scale)
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
                    color: Qt.rgba(0, 0, 0, 0.28)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.quickText, 0.16)

                    Text {
                        anchors.centerIn: parent
                        text: LockState.avatarLetter
                        color: Theme.withAlpha(Theme.quickText, 0.92)
                        font.family: "Google Sans Display"
                        font.pixelSize: Math.round(32 * root.scale)
                        font.weight: Font.Medium
                    }
                }
            }

            Item { width: 1; height: Math.round(18 * root.scale) }

            Item {
                width: parent.width
                height: root.fieldHeight

                Row {
                    id: inputRow

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * root.scale)
                    transform: Translate { x: root.shakeOffset }

                    Rectangle {
                        id: field

                        width: root.fieldWidth
                        height: root.fieldHeight
                        radius: height / 2
                        color: Qt.rgba(0, 0, 0, 0.32)
                        border.width: passwordInput.activeFocus
                                      ? Math.max(1, Math.round(2 * root.scale)) : 1
                        border.color: passwordInput.activeFocus
                                      ? Theme.accent : Theme.withAlpha(Theme.quickText, 0.16)

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
                                   ? Theme.accent : Theme.withAlpha(Theme.quickText, 0.55)
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Math.round(15 * root.scale)

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
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.quickIconOn
                            color: Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(15 * root.scale)
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
                            text: "Enter Password"
                            color: Theme.withAlpha(Theme.quickText, 0.42)
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(15 * root.scale)
                        }
                    }

                    // Кнопка сканера. Пока идёт сканирование — мягкая
                    // пульсация и акцентная рамка, чтобы было видно, что
                    // сканер «слушает».
                    Rectangle {
                        id: fingerprintButton

                        visible: LockState.fingerprintState !== "unavailable"
                        width: root.fingerprintSize
                        height: root.fingerprintSize
                        radius: width / 2
                        color: fingerprintHover.hovered
                               ? Theme.withAlpha(Theme.quickText, 0.10) : Qt.rgba(0, 0, 0, 0.32)
                        border.width: LockState.fingerprintState === "scanning" ? 2 : 1
                        border.color: LockState.fingerprintState === "scanning"
                                      ? Theme.withAlpha(Theme.accent, 0.75)
                                      : Theme.withAlpha(Theme.quickText, 0.16)

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
                                   ? Theme.accent
                                   : Theme.withAlpha(Theme.quickText,
                                                     LockState.fingerprintState === "checking" ? 0.4 : 0.85)
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Math.round(23 * root.scale)

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

            Text {
                id: statusLine

                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.statusText
                color: root.statusColor
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(13 * root.scale)

                Behavior on color {
                    ColorAnimation { duration: Theme.motionShort3 }
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
            return "Caps Lock is on";
        switch (LockState.fingerprintState) {
        case "scanning":
            return "Touch the fingerprint sensor";
        case "retry":
            return "Fingerprint not recognized, try again";
        case "busy":
            return "Fingerprint sensor is busy";
        case "error":
            return LockState.fingerprintHint !== "" ? LockState.fingerprintHint
                                                   : "Fingerprint is unavailable";
        case "unavailable":
            return "";
        }
        return "";
    }

    readonly property color statusColor: {
        if (LockState.statusKind === "error")
            return Theme.lowColor;
        if (LockState.fingerprintState === "retry" || LockState.fingerprintState === "busy")
            return Theme.warningColor;
        if (LockState.authenticating)
            return Theme.withAlpha(Theme.quickText, 0.66);
        if (LockState.capsLock)
            return Theme.warningColor;
        return Theme.withAlpha(Theme.quickText, 0.62);
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
