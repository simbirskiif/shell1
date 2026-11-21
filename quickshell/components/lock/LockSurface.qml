import QtQuick
import QtQuick.Effects
import Quickshell
import "../expressive"
import "../../singletons"
import "../../widgets/core"

// Содержимое экрана блокировки: размытые обои, часы, аватар, поле пароля
// и кнопка отпечатка. Одна и та же разметка создаётся на каждый экран
// в LockSession.
//
// Компонент — обычный Item (не WlSessionLockSurface): его можно показать
// в отдельном окне для проверки разметки, не блокируя сессию.
//
// Оформление — Material 3 Expressive: гигантские часы DisplayLarge с
// emphasized-весом, аватар в форме cookie/clover на tertiary-container,
// крупное поле-пилюля, орб отпечатка с пульсацией на пружине и большая
// плашка статуса. Безопасность не затронута: это только визуальные свойства,
// все условия/сигналы/таймеры аутентификации остались прежними.
Item {
    id: root

    // Масштаб от высоты экрана: на 1080p элементы базового размера, на
    // 1600p крупнее, на 768p мельче, но не настолько, чтобы поле ввода
    // теряло читаемость.
    readonly property real scale: Math.max(0.82, Math.min(1.30, root.height / 1080))
    readonly property int fieldWidth: Math.round(400 * root.scale)
    readonly property int fieldHeight: Math.round(64 * root.scale)
    readonly property int fingerprintSize: Math.round(64 * root.scale)
    readonly property int contentWidth: root.fieldWidth + root.fingerprintSize
                                        + Math.round(10 * root.scale)
    // Часы — герой-текст экрана: DisplayLarge, но ещё крупнее и с
    // emphasized-весом (wght 820, узкая ширина), чтобы читались «гигантскими».
    readonly property font clockFont: Qt.font({
        family: Theme.fontFamily,
        pixelSize: Math.round(Theme.typescale.displayLarge.size * 1.5 * root.scale),
        weight: Theme.weightEmphasized,
        letterSpacing: -1.5 * root.scale,
        variableAxes: ({ "wght": Theme.weightEmphasized, "wdth": Theme.widthTight, "opsz": 64 })
    })

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

        Behavior on opacity { SpringEffects {} }
        Behavior on scale { SpringSpatial {} }

        Column {
            id: column

            width: parent.width
            opacity: root.intro

            // Часы — герой-текст: самый крупный и жирный уровень экрана.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: clock.date.toLocaleTimeString(Qt.locale(), "HH:mm")
                color: Theme.scheme.onSurface
                font: root.clockFont
            }

            // Дата — labelLarge: следующий по иерархии, но спокойный уровень.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: Math.round(2 * root.scale)
                text: clock.date.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelLarge
            }

            Item { width: 1; height: Math.round(46 * root.scale) }

            // Аватар: инициал пользователя в выразительной форме. ~/.face
            // может не быть, а AccountsService в Wayland-сессии не гарантирован.
            Item {
                width: parent.width
                height: Math.round(96 * root.scale)

                MorphShape {
                    id: avatarShape

                    anchors.centerIn: parent
                    width: Math.round(92 * root.scale)
                    height: width
                    // Разблокировка читается и формой: cookie → clover.
                    shape: LockState.unlocking ? "clover" : "cookie"
                    color: Theme.tertiaryContainer
                    rotation: LockState.unlocking ? 12 : 0
                    Behavior on rotation { SpringSpatial {} }

                    Text {
                        anchors.centerIn: parent
                        text: LockState.avatarLetter
                        color: Theme.scheme.onTertiaryContainer
                        font: Theme.typeEmphasizedHeadlineSmall
                    }
                }
            }

            Item { width: 1; height: Math.round(18 * root.scale) }

            Item {
                width: parent.width
                height: root.fieldHeight

                // Карточка входа: тональная surface-container-high с низкой
                // альфой и радиусом-пилюлей — поле и сканер читаются как
                // одна поверхность M3.
                Rectangle {
                    anchors.fill: inputRow
                    anchors.margins: -Theme.space.sm
                    radius: height / 2
                    color: Theme.veil(Theme.surfaceContainerHigh, 0.55)
                }

                Row {
                    id: inputRow

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * root.scale)
                    transform: Translate { x: root.shakeOffset }

                    // Поле пароля — крупная пилюля с толстой обводкой
                    // primary; иконка замка живёт в цветном орбе, который
                    // при фокусе морфится в «печенье».
                    Rectangle {
                        id: field

                        width: root.fieldWidth
                        height: root.fieldHeight
                        radius: Theme.shape.full
                        color: Theme.veil(Theme.surfaceContainerHighest, 0.92)
                        border.width: passwordInput.activeFocus
                                      ? Math.max(3, Math.round(4 * root.scale))
                                      : Math.max(2, Math.round(3 * root.scale))
                        border.color: Theme.primary

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.motionShort3 }
                        }

                        MorphShape {
                            id: lockOrb

                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(12 * root.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(38 * root.scale)
                            height: width
                            shape: passwordInput.activeFocus ? "cookie" : "circle"
                            color: Theme.primaryContainer

                            Text {
                                anchors.centerIn: parent
                                text: "\uf023"
                                color: Theme.scheme.onPrimaryContainer
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Math.round(18 * root.scale)
                            }
                        }

                        TextInput {
                            id: passwordInput

                            anchors.left: lockOrb.right
                            anchors.leftMargin: Math.round(12 * root.scale)
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
                            font: Theme.typeTitleMedium
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
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodyLarge
                        }
                    }

                    // Кнопка сканера — выразительный орб. Сканирование
                    // читается формой (burst), цветом и пульсацией размера
                    // на пружине, чтобы было видно, что сканер «слушает».
                    Item {
                        id: fingerprintButton

                        property bool pulseOn: false

                        visible: LockState.fingerprintState !== "unavailable"
                        width: root.fingerprintSize
                        height: root.fingerprintSize
                        scale: pulseOn ? 1.10 : 1
                        Behavior on scale { SpringSpatial {} }

                        MorphShape {
                            anchors.fill: parent
                            shape: LockState.fingerprintState === "scanning" ? "burst"
                                 : fingerprintHover.containsMouse ? "squircle"
                                 : LockState.fingerprintState === "retry" ? "clover"
                                 : "cookie"
                            color: LockState.fingerprintState === "scanning"
                                   ? Theme.primaryContainer
                                   : fingerprintHover.containsMouse
                                     ? Theme.surfaceContainerHigh
                                     : Theme.surfaceContainerHighest
                            borderWidth: LockState.fingerprintState === "scanning" ? 0 : 1
                            borderColor: Theme.outlineVariant
                        }

                        Text {
                            id: fingerprintIcon

                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF0237)
                            color: LockState.fingerprintState === "scanning"
                                   ? Theme.scheme.onPrimaryContainer
                                   : Theme.withAlpha(Theme.scheme.onSurface,
                                                     LockState.fingerprintState === "checking"
                                                     ? Theme.disabledContent : 0.85)
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Math.round(27 * root.scale)
                        }

                        // Пульсация ожидания — не мигание прозрачности:
                        // форма «дышит» размером, а кадры дорисовывает
                        // spatial-пружина.
                        SequentialAnimation {
                            id: fingerprintPulse

                            running: LockState.fingerprintState === "scanning"
                            loops: Animation.Infinite
                            onStopped: fingerprintButton.pulseOn = false

                            PauseAnimation { duration: 580 }
                            PropertyAction { target: fingerprintButton; property: "pulseOn"; value: true }
                            PauseAnimation { duration: 580 }
                            PropertyAction { target: fingerprintButton; property: "pulseOn"; value: false }
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

            // Строка статуса — крупная плашка: ошибка — error-container
            // с текстом on-error-container, остальные состояния — нейтральная
            // полупрозрачная подложка.
            Rectangle {
                width: parent.width
                height: statusLine.implicitHeight + Theme.space.md * 2
                visible: root.statusText !== ""
                radius: Theme.shape.full
                color: root.statusPlateColor

                Behavior on color {
                    ColorAnimation { duration: Theme.motionShort3 }
                }

                Text {
                    id: statusLine

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.space.lg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.statusText
                    color: root.statusColor
                    font: Theme.typeTitleMedium

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

    // Тряска — пружинный импульс: from задаёт сдвиг, spatial-пружина
    // возвращает карточку с затухающим перелётом. Никаких покадровых
    // NumberAnimation.
    SpringSpatial {
        id: shake

        target: root
        property: "shakeOffset"
        from: Math.round(12 * root.scale)
        to: 0
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
        introAnimation.start();
    }

    // Вход контента — effects-пружина по прозрачности: без перелёта, поэтому
    // появление не мигает.
    SpringEffects {
        id: introAnimation

        target: root
        property: "intro"
        from: 0
        to: 1
    }
}
