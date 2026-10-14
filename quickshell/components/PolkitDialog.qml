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

    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
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

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(380, parent.width - 32)
            implicitHeight: cardColumn.implicitHeight + Theme.quickPadding * 2
            height: implicitHeight
            radius: Theme.quickRadius
            color: Theme.quickBackground
            border.width: 1
            border.color: Theme.quickBorder
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
                anchors.margins: Theme.quickPadding
                spacing: 10

                // Шапка: иконка действия от Polkit и текст запроса.
                Item {
                    width: parent.width
                    implicitHeight: headerColumn.implicitHeight

                    Item {
                        id: headerIcon

                        width: 22
                        height: 22
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
                            sourceSize: Qt.size(22, 22)
                            fillMode: Image.PreserveAspectFit
                        }

                        // Тема не знает иконку действия — рисуем замок.
                        Text {
                            anchors.centerIn: parent
                            visible: !root.hasActionIcon || actionIconImage.status === Image.Error
                            text: "\uf023"
                            color: Theme.accent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 16
                        }
                    }

                    Column {
                        id: headerColumn

                        anchors.left: headerIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.title
                            color: Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            visible: root.identityName !== ""
                            text: root.identityName
                            color: Theme.quickTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }

                // Сообщение PAM над полем ввода: ошибка или подсказка
                // (например, «отпечаток не распознан» после таймаута сканера).
                Text {
                    width: parent.width
                    visible: root.textMode && root.supplementary !== ""
                    text: root.supplementary
                    color: root.supplementaryIsError ? Theme.lowColor : Theme.quickTextDim
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                // Наша ошибка, когда PAM о причине молчит.
                Text {
                    width: parent.width
                    visible: root.hasFailed && !(root.textMode && root.supplementaryIsError)
                    text: "Не удалось войти, попробуйте ещё раз"
                    color: Theme.lowColor
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                // Статус биометрии: PAM не ждёт текста, но прислал инструкцию.
                Rectangle {
                    id: biometricBlock

                    width: parent.width
                    height: Math.max(biometricIcon.implicitHeight, biometricText.implicitHeight) + 24
                    visible: root.biometricMode
                    radius: Theme.quickTileRadius
                    color: Theme.quickTile
                    border.width: 1
                    border.color: root.supplementaryIsError
                                  ? Theme.withAlpha(Theme.lowColor, 0.55) : Theme.quickBorder

                    Text {
                        id: biometricIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.supplementaryIsError ? "\uf06e" : "\uf0237"
                        color: root.supplementaryIsError ? Theme.lowColor : Theme.accent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 22

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
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.supplementary
                        color: root.supplementaryIsError ? Theme.lowColor : Theme.quickText
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }

                // Тихий старт PAM: ни текста, ни сообщения — нейтральное
                // ожидание вместо иконки отпечатка, которой может и не быть.
                Rectangle {
                    width: parent.width
                    height: 56
                    visible: root.waitingMode
                    radius: Theme.quickTileRadius
                    color: Theme.quickTile

                    Row {
                        anchors.centerIn: parent
                        spacing: 10

                        LoadingIndicator {
                            width: 18
                            height: 18
                        }

                        Text {
                            height: 18
                            verticalAlignment: Text.AlignVCenter
                            text: "Ожидание ответа от модуля безопасности…"
                            color: Theme.quickTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                    }
                }

                // Поле ввода пароля.
                Rectangle {
                    id: field

                    width: parent.width
                    height: 44
                    visible: root.fieldVisible
                    radius: Theme.quickTileRadius
                    color: Theme.quickTile
                    opacity: root.isSubmitting ? 0.6 : 1
                    border.width: passwordInput.activeFocus ? 2 : 1
                    border.color: root.hasFailed ? Theme.lowColor
                                  : (passwordInput.activeFocus ? Theme.accent : Theme.quickBorder)
                    Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: root.textMode && !root.isSubmitting
                        echoMode: root.flow && root.flow.responseVisible
                                  ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                        color: Theme.quickText
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.quickIconOn
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        onAccepted: root.submit()
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text === "" && root.textMode && !root.isSubmitting
                        text: root.inputPrompt !== "" ? root.inputPrompt : "Пароль"
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }

                Row {
                    width: parent.width
                    height: 36
                    layoutDirection: Qt.RightToLeft
                    spacing: 8

                    DialogButton {
                        text: "Подтвердить"
                        primary: true
                        busy: root.isSubmitting
                        enabled: root.textMode && passwordInput.text.length > 0 && !root.isSubmitting
                        onTriggered: root.submit()
                    }

                    DialogButton {
                        text: "Отмена"
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

        width: (button.busy ? busyLabel.implicitWidth + 36 : label.implicitWidth + 34)
        height: 36
        radius: height / 2
        color: button.primary ? Theme.accent : "transparent"
        border.width: button.primary ? 0 : 1
        border.color: Theme.quickBorder
        opacity: button.enabled ? 1 : 0.45

        Text {
            id: label

            anchors.centerIn: parent
            visible: !button.busy
            text: button.text
            color: button.primary ? Theme.quickIconOn : Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        // Пока кнопка занята, ширину держит невидимая подпись: иначе она
        // скакала бы при появлении спиннера.
        Text {
            id: busyLabel

            visible: false
            text: button.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        LoadingIndicator {
            anchors.centerIn: parent
            width: 18
            height: 18
            visible: button.busy
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
