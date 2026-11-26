import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "quick"
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

    readonly property string title: root.flow !== null && root.flow.message !== ""
                                    ? root.flow.message : I18n.tr("dialogs.polkit.title")
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

        NumberAnimation {
            id: showFade

            target: backdrop
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.motionShort4
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandardDecelerate
        }

        // Клик мимо карточки — отказ от аутентификации.
        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }

        // Карточка диалога: surface-container-high и радиус shape.xl.
        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(380, parent.width - 32)
            implicitHeight: cardColumn.implicitHeight + Theme.space.xl * 2
            height: implicitHeight
            radius: Theme.shape.xl
            color: Theme.surfaceContainerHigh
            transform: Translate { x: root.shakeOffset }

            // При переходе «сканер → пароль» в колонке появляется поле ввода,
            // и карточка мягко раскрывается под него.
            Behavior on implicitHeight {
                MotionNumber {
                    duration: Theme.motionMedium1
                    curve: Theme.curveEmphasized
                }
            }

            NumberAnimation {
                id: cardIn

                target: card
                property: "scale"
                from: Theme.motionFadeThroughScale
                to: 1
                duration: Theme.motionShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }

            SequentialAnimation {
                id: shake

                NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 50; easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "shakeOffset"; to: -5; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "shakeOffset"; to: 5; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 70; easing.type: Easing.OutQuad }
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
                spacing: Theme.space.sm

                // Шапка: иконка действия от Polkit и текст запроса.
                Item {
                    width: parent.width
                    implicitHeight: headerColumn.implicitHeight

                    Item {
                        id: headerIcon

                        width: Theme.iconSize.lg
                        height: Theme.iconSize.lg
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 1

                        Image {
                            id: actionIconImage

                            anchors.fill: parent
                            // hasThemeIcon ещё не гарантирует, что файл иконки
                            // читается: при ошибке показываем глиф замка.
                            visible: root.hasActionIcon && actionIconImage.status !== Image.Error
                            source: root.actionIcon
                            sourceSize: Qt.size(Theme.iconSize.lg, Theme.iconSize.lg)
                            fillMode: Image.PreserveAspectFit
                        }

                        // Тема не знает иконку действия — рисуем замок.
                        Text {
                            anchors.centerIn: parent
                            visible: !root.hasActionIcon || actionIconImage.status === Image.Error
                            text: "\uf023"
                            color: Theme.primary
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.lg
                        }
                    }

                    Column {
                        id: headerColumn

                        anchors.left: headerIcon.right
                        anchors.leftMargin: Theme.space.sm
                        anchors.right: parent.right
                        spacing: Theme.space.xs / 2

                        Text {
                            width: parent.width
                            text: root.title
                            color: Theme.scheme.onSurface
                            font: Theme.typeHeadlineSmall
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
                    radius: Theme.shape.xs
                    color: root.supplementaryIsError ? Theme.errorContainer
                                                     : Theme.surfaceContainerHighest

                    Text {
                        id: supplementaryLabel

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.space.md
                        anchors.rightMargin: Theme.space.md
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
                    radius: Theme.shape.xs
                    color: Theme.errorContainer

                    Text {
                        id: failedLabel

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.space.md
                        anchors.rightMargin: Theme.space.md
                        text: I18n.tr("dialogs.polkit.failed")
                        color: Theme.scheme.onErrorContainer
                        wrapMode: Text.WordWrap
                        font: Theme.typeBodyMedium
                    }
                }

                // Статус биометрии: PAM не ждёт текста, но прислал инструкцию.
                Rectangle {
                    id: biometricBlock

                    width: parent.width
                    height: Math.max(biometricIcon.implicitHeight, biometricText.implicitHeight)
                            + Theme.space.xl
                    visible: root.biometricMode
                    radius: Theme.shape.md
                    color: root.supplementaryIsError ? Theme.errorContainer
                                                     : Theme.surfaceContainerHighest

                    Text {
                        id: biometricIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.lg
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.supplementaryIsError ? "\uf06e" : "\uf0237"
                        color: root.supplementaryIsError ? Theme.scheme.onErrorContainer
                                                         : Theme.primary
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.lg

                        // Сканер ждёт палец: мягкая пульсация иконки.
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.biometricMode && !root.supplementaryIsError
                            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        id: biometricText

                        anchors.left: biometricIcon.right
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
                    radius: Theme.shape.md
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
                            text: I18n.tr("dialogs.polkit.waiting")
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodyMedium
                        }
                    }
                }

                // Поле ввода пароля M3: surface-container-highest, shape.xs,
                // обводка outline / primary в фокусе / error при ошибке.
                Rectangle {
                    id: field

                    width: parent.width
                    height: Theme.listItemHeight
                    visible: root.fieldVisible
                    radius: Theme.shape.xs
                    color: Theme.surfaceContainerHighest
                    opacity: root.isSubmitting ? 0.6 : 1
                    border.width: passwordInput.activeFocus ? 2 : 1
                    border.color: root.hasFailed ? Theme.error
                                  : (passwordInput.activeFocus ? Theme.primary : Theme.outline)
                    Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: Theme.space.lg
                        anchors.rightMargin: Theme.space.lg
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: root.textMode && !root.isSubmitting
                        echoMode: root.flow && root.flow.responseVisible
                                  ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                        color: Theme.scheme.onSurface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.scheme.onPrimary
                        font: Theme.typeBodyLarge
                        onAccepted: root.submit()
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.lg
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text === "" && root.textMode && !root.isSubmitting
                        text: root.inputPrompt !== "" ? root.inputPrompt
                                                      : I18n.tr("dialogs.polkit.password")
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodySmall
                    }
                }

                Row {
                    width: parent.width
                    height: Theme.buttonHeight
                    layoutDirection: Qt.RightToLeft
                    spacing: Theme.space.sm

                    DialogButton {
                        text: I18n.tr("common.confirm")
                        primary: true
                        busy: root.isSubmitting
                        enabled: root.textMode && passwordInput.text.length > 0 && !root.isSubmitting
                        onTriggered: root.submit()
                    }

                    DialogButton {
                        text: I18n.tr("common.cancel")
                        onTriggered: root.cancel()
                    }
                }
            }
        }
    }

    component DialogButton: Rectangle {
        id: button

        property string text: ""
        property bool primary: false
        property bool busy: false

        signal triggered()

        // Контейнер и подпись M3: залитая — primary/on-primary, текстовая —
        // прозрачная с подписью primary; недоступная — 12 %/38 % on-surface.
        // Пока идёт проверка, контейнер primary-container: круговой индикатор
        // в оболочке рисуется primary, и на primary его было бы не видно.
        readonly property color containerColor: {
            if (!button.primary)
                return "transparent";
            if (button.busy)
                return Theme.primaryContainer;
            if (!button.enabled)
                return Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContainer);
            return Theme.primary;
        }
        readonly property color labelColor: {
            if (!button.enabled)
                return Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContent);
            return button.primary ? Theme.scheme.onPrimary : Theme.primary;
        }

        width: (button.busy ? busyLabel.implicitWidth + Theme.space.xl * 2
                            : label.implicitWidth + Theme.space.xl * 2)
        height: Theme.buttonHeight
        radius: Theme.shape.full
        color: button.containerColor

        // Слой состояния: наведение поверх контейнера.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: button.primary ? Theme.scheme.onPrimary : Theme.primary
            opacity: buttonHover.containsMouse && button.enabled ? Theme.stateHover : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            id: label

            anchors.centerIn: parent
            visible: !button.busy
            text: button.text
            color: button.labelColor
            font: Theme.typeLabelLarge
        }

        // Пока кнопка занята, ширину держит невидимая подпись: иначе она
        // скакала бы при появлении спиннера.
        Text {
            id: busyLabel

            visible: false
            text: button.text
            font: Theme.typeLabelLarge
        }

        LoadingIndicator {
            anchors.centerIn: parent
            width: Theme.iconSize.md
            height: Theme.iconSize.md
            visible: button.busy
        }

        MouseArea {
            id: buttonHover

            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
