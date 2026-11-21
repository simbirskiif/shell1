import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "quick"
import "expressive"
import "../singletons"

// Модальное окно агента Polkit: пароль или биометрия.
//
// Одна и та же разметка обслуживает два сценария PAM:
//   * обычный пароль — PAM просит текст (isResponseRequired), показываем поле;
//   * сканер (pam_fprintd) — текста PAM не просит, но присылает
//     supplementaryMessage («приложите палец…»), показываем блок статуса.
//
// Ключевая тонкость: `isResponseRequired === false` означает не только
// «работает сканер». Он равен false ещё в первые миллисекунды сессии PAM
// и после submit(), пока проверяется хэш. Поэтому пауза на старте
// прикрыта таймером (чтобы на ПК без сканера окно не мигало отпечатком),
// а проверка пароля — своим флагом isSubmitting.
//
// Отдельная поверхность на весь экран, как у PasswordDialog: попап быстрого
// меню не может забрать клавиатурный фокус, а PanelWindow — может.
//
// Оформление — Material 3 Expressive: карточка радиуса 32, акцентный орб
// (cookie → burst при ошибке), высокое поле-пилюля, плашки с крупным
// радиусом и кнопки на пружине.
PanelWindow {
    id: root

    required property ShellScreen dialogScreen
    // Слушатель D-Bus один на оболочку и живёт в shell.qml: два агента
    // на сессии перехватывали бы запросы друг у друга. Диалог на каждом
    // экране лишь показывает состояние общего агента.
    required property PolkitAgent agent

    readonly property string screenName: root.dialogScreen ? root.dialogScreen.name : ""
    // Запрос показываем только на экране с фокусом, а не на всех сразу.
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    // Текущий процесс аутентификации; null, когда запроса нет.
    readonly property AuthFlow flow: root.agent ? root.agent.flow : null

    // --- Локальное состояние ----------------------------------------------
    // Пароль отправлен, PAM проверяет его: isResponseRequired в этот момент
    // уже false, поэтому сами не даём отправить пароль дважды.
    property bool isSubmitting: false
    // Хотя бы одна попытка входа провалилась.
    property bool hasFailed: false
    // PAM молчит дольше паузы: показываем нейтральное ожидание.
    property bool waitingForModule: false
    // Смещение карточки для анимации тряски по оси X.
    property real shakeOffset: 0

    // --- Производные состояния --------------------------------------------
    // PAM ждёт текстовый ответ (пароль).
    readonly property bool textMode: root.flow !== null && root.flow.isResponseRequired
    readonly property string supplementary: root.flow ? root.flow.supplementaryMessage : ""
    readonly property bool supplementaryIsError: root.flow ? root.flow.supplementaryIsError : false
    readonly property string inputPrompt: root.flow ? root.flow.inputPrompt : ""
    // Поле показываем, пока PAM ждёт ответ и пока проверяет отправленный.
    readonly property bool fieldVisible: root.textMode || root.isSubmitting
    // Модуль просит действие без текста (обычно pam_fprintd).
    readonly property bool biometricMode: root.flow !== null && !root.textMode
                                           && !root.isSubmitting && root.supplementary !== ""
    // Короткая пауза PAM без сообщений: нейтральное ожидание.
    readonly property bool waitingMode: root.flow !== null && !root.textMode
                                         && !root.isSubmitting && root.supplementary === ""
                                         && root.waitingForModule
    // Ошибка (своя или от PAM) — акцент карточки становится error-container,
    // а форма орба «взрывается» в burst.
    readonly property bool errorAccent: root.hasFailed || root.supplementaryIsError

    readonly property string title: root.flow !== null && root.flow.message !== ""
                                    ? root.flow.message : "Требуется аутентификация"
    // Имя пользователя из Polkit. `displayName` при отсутствии полного имени
    // равен логину, поэтому отдельный fallback не нужен.
    readonly property string identityName: {
        const identity = root.flow ? root.flow.selectedIdentity : null;
        if (!identity)
            return "";
        const full = identity.displayName;
        return typeof full === "string" ? full : "";
    }
    // Иконка действия от Polkit. Если тема её не знает, показываем глиф замка:
    // iconPath() в этом случае отдаёт пустую картинку-заглушку.
    readonly property string actionIconName: root.flow && root.flow.iconName ? root.flow.iconName : ""
    readonly property bool hasActionIcon: root.actionIconName !== ""
                                          && Quickshell.hasThemeIcon(root.actionIconName)
    readonly property string actionIcon: root.hasActionIcon
                                         ? Quickshell.iconPath(root.actionIconName) : ""

    screen: dialogScreen
    visible: root.agent.isActive
             && (root.focusedScreenName === "" || root.focusedScreenName === root.screenName)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-polkit"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Пауза перед нейтральным ожиданием: на ПК без сканера PAM за 200 мс
    // успевает прислать запрос пароля, поэтому иконка отпечатка не мигает.
    Timer {
        id: quietProbe

        interval: 200
        repeat: false
        running: root.flow !== null && !root.textMode && !root.isSubmitting
                 && root.supplementary === "" && !root.waitingForModule
        onTriggered: root.waitingForModule = true
    }

    Connections {
        target: root.agent

        // Новый запрос: состояние прошлой попытки не переносим.
        function onAuthenticationRequestStarted() {
            root.isSubmitting = false;
            root.hasFailed = false;
            root.waitingForModule = false;
            passwordInput.text = "";
        }
    }

    Connections {
        target: root.flow
        enabled: root.flow !== null

        // PAM сам поднимает новую сессию: окно не закрываем, показываем
        // ошибку и очищаем поле, чтобы не отправлять его повторно.
        function onAuthenticationFailed() {
            root.isSubmitting = false;
            root.hasFailed = true;
            root.waitingForModule = false;
            passwordInput.text = "";
            shake.restart();
        }

        function onAuthenticationSucceeded() {
            root.isSubmitting = false;
            root.hasFailed = false;
        }

        function onAuthenticationRequestCancelled() {
            root.isSubmitting = false;
        }

        // PAM снова ждёт текст: снимаем флаг проверки и ставим фокус.
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired) {
                root.isSubmitting = false;
                root.waitingForModule = false;
                Qt.callLater(() => passwordInput.forceActiveFocus());
            }
        }

        // Модуль прислал инструкцию или ошибку — ждать больше нечего.
        function onSupplementaryMessageChanged() {
            root.waitingForModule = false;
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            // Поверхность создаётся асинхронно: появление запускаем явно,
            // иначе анимация стартует до готовности окна.
            showFade.restart();
            cardIn.restart();
            if (root.textMode)
                Qt.callLater(() => passwordInput.forceActiveFocus());
        } else {
            // Пароль не должен переживать закрытие окна.
            backdrop.opacity = 0;
            passwordInput.text = "";
            root.isSubmitting = false;
            root.hasFailed = false;
            root.waitingForModule = false;
            root.shakeOffset = 0;
        }
    }

    // Отправить введённый пароль в PAM.
    function submit() {
        if (root.flow === null || !root.flow.isResponseRequired || root.isSubmitting)
            return;
        const value = passwordInput.text;
        if (value.length === 0)
            return;
        root.isSubmitting = true;
        root.hasFailed = false;
        root.waitingForModule = false;
        root.flow.submit(value);
    }

    // Отменить запрос: PAM получит отказ, окно закроет агент.
    function cancel() {
        if (root.flow !== null)
            root.flow.cancelAuthenticationRequest();
    }

    // Escape отменяет запрос из любого состояния, даже когда поле не в фокусе.
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.cancel()
    }

    // Затемнение фона — ролью scrim.
    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Theme.scrimOverlay
        opacity: 0

        SpringEffects {
            id: showFade

            target: backdrop
            property: "opacity"
            to: 1
        }

        // Клик мимо карточки — отказ от аутентификации.
        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }

        // Карточка диалога: surface-container-high и крупный радиус 32.
        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(400, parent.width - 32)
            implicitHeight: cardColumn.implicitHeight + Theme.space.xl * 2
            height: implicitHeight
            radius: Theme.shape.xlIncreased
            color: Theme.surfaceContainerHigh
            transform: Translate { x: root.shakeOffset }

            // При переходе «сканер → пароль» в колонке появляется поле ввода,
            // и карточка упруго раскрывается под него.
            Behavior on implicitHeight { SpringSpatial {} }

            SpringSpatial {
                id: cardIn

                target: card
                property: "scale"
                from: Theme.motionFadeThroughScale
                to: 1
            }

            // Неверный пароль — карточка коротко «дёргается»: смещение задаёт
            // from, а возвращает spatial-пружина с затухающим перелётом.
            SpringSpatial {
                id: shake

                target: root
                property: "shakeOffset"
                from: Theme.space.md
                to: 0
            }

            // Клики по карточке не должны её закрывать.
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: cardColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space.xl
                spacing: Theme.space.md

                // Шапка: крупный орб-акцент с иконкой действия Polkit.
                // Ошибка читается формой: cookie/clover → burst.
                Item {
                    width: parent.width
                    implicitHeight: Math.max(headerOrb.height, headerColumn.implicitHeight)

                    MorphShape {
                        id: headerOrb

                        width: Theme.touchTarget + Theme.space.md
                        height: width
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        shape: root.errorAccent ? "burst"
                             : root.biometricMode ? "clover"
                             : "cookie"
                        color: root.errorAccent ? Theme.errorContainer : Theme.primaryContainer

                        Image {
                            id: actionIconImage

                            anchors.centerIn: parent
                            width: Theme.iconSize.lg + Theme.space.xs
                            height: width
                            // hasThemeIcon ещё не гарантирует, что файл иконки
                            // читается: при ошибке показываем глиф замка.
                            visible: root.hasActionIcon && actionIconImage.status !== Image.Error
                            source: root.actionIcon
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                        }

                        // Тема не знает иконку действия — рисуем замок.
                        Text {
                            anchors.centerIn: parent
                            visible: !root.hasActionIcon || actionIconImage.status === Image.Error
                            text: "\uf023"
                            color: root.errorAccent ? Theme.scheme.onErrorContainer
                                                    : Theme.scheme.onPrimaryContainer
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.lg + Theme.space.xs
                        }
                    }

                    Column {
                        id: headerColumn

                        anchors.left: headerOrb.right
                        anchors.leftMargin: Theme.space.lg
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space.xs / 2

                        Text {
                            width: parent.width
                            text: root.title
                            color: Theme.scheme.onSurface
                            font: Theme.typeEmphasizedHeadlineSmall
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            visible: root.identityName !== ""
                            text: root.identityName
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodyMedium
                            elide: Text.ElideRight
                        }
                    }
                }

                // Сообщение PAM над полем ввода: ошибка или подсказка
                // (например, «отпечаток не распознан» после таймаута сканера).
                // Ошибка — error-container, подсказка — нейтральная поверхность.
                Rectangle {
                    width: parent.width
                    height: supplementaryLabel.implicitHeight + Theme.space.md * 2
                    visible: root.textMode && root.supplementary !== ""
                    radius: Theme.shape.lg
                    color: root.supplementaryIsError ? Theme.errorContainer
                                                     : Theme.surfaceContainerHighest

                    Text {
                        id: supplementaryLabel

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.space.lg
                        anchors.rightMargin: Theme.space.lg
                        text: root.supplementary
                        color: root.supplementaryIsError ? Theme.scheme.onErrorContainer
                                                         : Theme.scheme.onSurfaceVariant
                        wrapMode: Text.WordWrap
                        font: Theme.typeBodyMedium
                    }
                }

                // Наша ошибка, когда PAM о причине молчит.
                Rectangle {
                    width: parent.width
                    height: failedLabel.implicitHeight + Theme.space.md * 2
                    visible: root.hasFailed && !(root.textMode && root.supplementaryIsError)
                    radius: Theme.shape.lg
                    color: Theme.errorContainer

                    Text {
                        id: failedLabel

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.space.lg
                        anchors.rightMargin: Theme.space.lg
                        text: "Не удалось войти, попробуйте ещё раз"
                        color: Theme.scheme.onErrorContainer
                        wrapMode: Text.WordWrap
                        font: Theme.typeBodyMedium
                    }
                }

                // Статус биометрии: PAM не ждёт текста, но прислал инструкцию.
                // Орб-отпечаток пульсирует на пружине, пока сканер «слушает».
                Rectangle {
                    id: biometricBlock

                    width: parent.width
                    height: Math.max(biometricOrb.height, biometricText.implicitHeight)
                            + Theme.space.xl
                    visible: root.biometricMode
                    radius: Theme.shape.lg
                    color: root.supplementaryIsError ? Theme.errorContainer
                                                     : Theme.surfaceContainerHighest

                    MorphShape {
                        id: biometricOrb

                        property bool pulseOn: false

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.lg
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.touchTarget
                        height: Theme.touchTarget
                        shape: root.supplementaryIsError ? "burst" : "cookie"
                        color: root.supplementaryIsError ? Theme.error
                                                         : Theme.tertiaryContainer
                        scale: pulseOn ? 1.08 : 1
                        Behavior on scale { SpringSpatial {} }

                        Text {
                            id: biometricIcon

                            anchors.centerIn: parent
                            text: root.supplementaryIsError ? "\uf06e" : "\uf0237"
                            color: root.supplementaryIsError ? Theme.scheme.onError
                                                             : Theme.scheme.onTertiaryContainer
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.lg
                        }

                        // Сканер ждёт палец: мягкая пульсация формы/размера.
                        SequentialAnimation {
                            running: root.biometricMode && !root.supplementaryIsError
                            loops: Animation.Infinite
                            onStopped: biometricOrb.pulseOn = false

                            PauseAnimation { duration: 620 }
                            PropertyAction { target: biometricOrb; property: "pulseOn"; value: true }
                            PauseAnimation { duration: 620 }
                            PropertyAction { target: biometricOrb; property: "pulseOn"; value: false }
                        }
                    }

                    Text {
                        id: biometricText

                        anchors.left: biometricOrb.right
                        anchors.leftMargin: Theme.space.md
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.lg
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.supplementary
                        color: root.supplementaryIsError ? Theme.scheme.onErrorContainer
                                                         : Theme.scheme.onSurface
                        wrapMode: Text.WordWrap
                        font: Theme.typeBodyMedium
                    }
                }

                // Тихий старт PAM: ни текста, ни сообщения — нейтральное
                // ожидание вместо иконки отпечатка, которой может и не быть.
                Rectangle {
                    width: parent.width
                    height: Theme.listItemHeight
                    visible: root.waitingMode
                    radius: Theme.shape.lg
                    color: Theme.surfaceContainerHighest

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.space.sm

                        LoadingIndicator {
                            width: Theme.iconSize.md
                            height: Theme.iconSize.md
                        }

                        Text {
                            height: Theme.iconSize.md
                            verticalAlignment: Text.AlignVCenter
                            text: "Ожидание ответа от модуля безопасности…"
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodyMedium
                        }
                    }
                }

                // Поле ввода пароля Expressive: высокий контейнер-пилюля (56)
                // с толстой обводкой primary / error.
                Rectangle {
                    id: field

                    width: parent.width
                    height: Theme.listItemHeight
                    visible: root.fieldVisible
                    radius: Theme.shape.full
                    color: Theme.surfaceContainerHighest
                    opacity: root.isSubmitting ? 0.6 : 1
                    border.width: root.hasFailed || passwordInput.activeFocus ? 4 : 3
                    border.color: root.hasFailed ? Theme.error : Theme.primary
                    Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: Theme.space.xl
                        anchors.rightMargin: Theme.space.xl
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: root.textMode && !root.isSubmitting
                        echoMode: root.flow && root.flow.responseVisible
                                  ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                        color: Theme.scheme.onSurface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.scheme.onPrimary
                        font: Theme.typeTitleMedium
                        onAccepted: root.submit()
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.xl
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text === "" && root.textMode && !root.isSubmitting
                        text: root.inputPrompt !== "" ? root.inputPrompt : "Пароль"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }
                }

                Row {
                    width: parent.width
                    height: Theme.touchTarget
                    layoutDirection: Qt.RightToLeft
                    spacing: Theme.space.sm

                    // Подтверждение — залитая пилюля на spatial-пружине.
                    // Пока PAM проверяет пароль, контейнер primary-container:
                    // морфящаяся клякса индикатора рисуется primary, и на
                    // primary её было бы не видно.
                    Rectangle {
                        id: submitButton

                        readonly property bool canSubmit: root.textMode
                                                          && passwordInput.text.length > 0
                                                          && !root.isSubmitting

                        width: (root.isSubmitting ? submitBusyLabel.implicitWidth
                                                  : submitLabel.implicitWidth) + Theme.space.xl * 2
                        height: Theme.touchTarget
                        radius: Theme.shape.full
                        color: root.isSubmitting
                               ? Theme.primaryContainer
                               : (submitButton.canSubmit
                                  ? Theme.primary
                                  : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContainer))
                        scale: submitHover.pressed && submitButton.canSubmit ? 0.93
                             : (submitHover.containsMouse && submitButton.canSubmit ? 1.03 : 1)
                        Behavior on scale { SpringSpatialFast {} }

                        // Слой состояния: наведение поверх контейнера.
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.scheme.onPrimary
                            opacity: submitHover.containsMouse && submitButton.canSubmit ? Theme.stateHover : 0
                            Behavior on opacity { SpringEffects {} }
                        }

                        Text {
                            id: submitLabel

                            anchors.centerIn: parent
                            visible: !root.isSubmitting
                            text: "Подтвердить"
                            color: submitButton.canSubmit
                                   ? Theme.scheme.onPrimary
                                   : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContent)
                            font: Theme.typeEmphasizedLabelLarge
                        }

                        // Пока кнопка занята, ширину держит невидимая подпись:
                        // иначе она скакала бы при появлении индикатора.
                        Text {
                            id: submitBusyLabel

                            visible: false
                            text: "Подтвердить"
                            font: Theme.typeEmphasizedLabelLarge
                        }

                        LoadingIndicator {
                            anchors.centerIn: parent
                            width: Theme.iconSize.md
                            height: Theme.iconSize.md
                            visible: root.isSubmitting
                        }

                        MouseArea {
                            id: submitHover

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: submitButton.canSubmit
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submit()
                        }
                    }

                    // Отмена — текстовая кнопка-пилюля с подписью primary.
                    Rectangle {
                        id: cancelButton

                        width: cancelLabel.implicitWidth + Theme.space.xl * 2
                        height: Theme.touchTarget
                        radius: Theme.shape.full
                        color: "transparent"
                        scale: cancelHover.pressed ? 0.94 : (cancelHover.containsMouse ? 1.02 : 1)
                        Behavior on scale { SpringSpatialFast {} }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.stateLayer(Theme.primary, Theme.stateHover)
                            opacity: cancelHover.containsMouse ? 1 : 0
                            Behavior on opacity { SpringEffects {} }
                        }

                        Text {
                            id: cancelLabel

                            anchors.centerIn: parent
                            text: "Отмена"
                            color: Theme.primary
                            font: Theme.typeLabelLarge
                        }

                        MouseArea {
                            id: cancelHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancel()
                        }
                    }
                }
            }
        }
    }

}
