import QtQuick
import Quickshell
import ".."
import "../../singletons"

// Содержимое раскрытого дока: поиск, анимированный список приложений и
// настройки дока. Это «большая панель», в которую плавно превращается
// компактная полоса.
Item {
    id: root

    required property string screenName

    signal closeRequested()

    // Настройки открываются поверх списка, а не отдельным окном: панель уже
    // держит и маску ввода, и фокус-граб для закрытия по клику мимо.
    // Состояние в DockState, чтобы панель переживала пересоздание и
    // переключалась по IPC.
    readonly property bool settingsOpen: DockState.settingsOpen

    // Накопленный оверскролл за верхним краем списка. Когда его достаточно,
    // панель закрывается — как «потянуть меню вверх».
    property real overscroll: 0

    // Одна порция колеса/тачпада: прокрутка списка и закрытие по
    // оверскроллу. Вынесено функцией, чтобы обработчик оставался тонким.
    function applyWheelDelta(dy) {
        if (appList.contentY <= 0.5 && dy > 0) {
            root.overscroll += dy;
            if (root.overscroll >= Theme.dockOverscrollClose) {
                root.overscroll = 0;
                overscrollReset.stop();
                DockState.hide();
            } else {
                overscrollReset.restart();
            }
            return;
        }

        root.overscroll = 0;
        overscrollReset.stop();
        const maxY = Math.max(0, appList.contentHeight - appList.height);
        appList.contentY = Math.max(0, Math.min(maxY,
            appList.contentY - dy * DockSettings.scrollFactor));
    }

    // Отфильтрованный список. ScriptModel сравнивает старый и новый массивы
    // и отправляет ListView точечные insert/remove/move, поэтому уцелевшие
    // делегаты не пересоздаются и переезжают анимацией displaced.
    ScriptModel {
        id: filtered
        objectProp: "id"
        values: {
            const query = DockState.query.trim().toLowerCase();
            if (query === "")
                return DockApps.all;
            return DockApps.all.filter(entry =>
                String(entry.name).toLowerCase().includes(query));
        }
    }

    // Синхронизация поля с внешним запросом (IPC/сброс при закрытии) и
    // фокус при раскрытии панели.
    Connections {
        target: DockState

        function onQueryChanged() {
            searchField.setText(DockState.query);
        }

        function onExpandedChanged() {
            if (DockState.expanded && !DockState.settingsOpen)
                searchField.focusInput();
        }

        function onSettingsOpenChanged() {
            if (DockState.expanded && !DockState.settingsOpen)
                searchField.focusInput();
        }

        function onShownChanged() {
            if (!DockState.shown)
                searchField.setText("");
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: DockState.expanded

        onActivated: {
            if (DockState.settingsOpen) {
                DockState.settingsOpen = false;
                return;
            }
            if (DockState.query !== "") {
                DockState.query = "";
                return;
            }
            DockState.hide();
        }
    }

    // Шапка остаётся на месте, содержимое прокручивается.
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34

        Text {
            id: titleText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.settingsOpen ? "Настройки дока" : "Приложения"
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: titleText.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.settingsOpen
            text: "· " + appList.count
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: header.verticalCenter
        spacing: 2

        DockIconButton {
            size: 34
            glyphSize: 14
            icon: "\uf013"
            accented: root.settingsOpen

            onClicked: DockState.settingsOpen = !DockState.settingsOpen
        }

        DockIconButton {
            size: 34
            glyphSize: 14
            icon: "\uf00d"

            onClicked: root.closeRequested()
        }
    }

    // --- строка поиска ----------------------------------------------------
    DockSearchField {
        id: searchField
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        opacity: root.settingsOpen ? 0 : 1
        visible: opacity > 0.001
        Behavior on opacity {
            MotionNumber {
                duration: Theme.dockFadeDuration
                curve: Theme.curveEmphasized
            }
        }

        onEdited: value => DockState.query = value
    }

    // --- список приложений ------------------------------------------------
    ListView {
        id: appList
        anchors.top: searchField.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: filtered
        enabled: !root.settingsOpen
        opacity: root.settingsOpen ? 0 : 1
        visible: opacity > 0.001
        Behavior on opacity {
            MotionNumber {
                duration: Theme.dockFadeDuration
                curve: Theme.curveEmphasized
            }
        }

        delegate: DockListItem {
            required property var modelData

            entry: modelData
        }

        // Удаляемый элемент остаётся видимым до конца перехода: ListView
        // сам держит его в сцене, поэтому opacity/scale анимируем явно.
        remove: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: 200
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    to: 0.8
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.8
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Соседи переезжают на освободившиеся места; add/removeDisplaced
        // заданы явно, чтобы не полагаться на наследование.
        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        addDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        removeDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }

    // Свой обработчик колеса: у ListView нет настройки чувствительности,
    // а оверскролл вверх должен закрывать панель. Слой прозрачен для кликов
    // и касаний — они уходят строкам под ним.
    Item {
        anchors.fill: appList
        visible: !root.settingsOpen

        WheelHandler {
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
            orientation: Qt.Vertical

            onWheel: (event) => {
                const dy = event.pixelDelta.y !== 0
                    ? event.pixelDelta.y
                    : event.angleDelta.y * 0.5;
                if (dy === 0)
                    return;
                root.applyWheelDelta(dy);
                event.accepted = true;
            }
        }

        Timer {
            id: overscrollReset
            interval: 220
            onTriggered: root.overscroll = 0
        }
    }

    Text {
        anchors.centerIn: appList
        visible: !root.settingsOpen && appList.count === 0
        text: DockState.query !== "" ? "Ничего не найдено" : "Список приложений пуст"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    // --- настройки дока ---------------------------------------------------
    DockPanelSettings {
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        enabled: root.settingsOpen
        opacity: root.settingsOpen ? 1 : 0
        visible: opacity > 0.001
        Behavior on opacity {
            MotionNumber {
                duration: Theme.dockFadeDuration
                curve: Theme.curveEmphasized
            }
        }
    }
}
