import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "utils.js" as Utils

PlasmoidItem {
    id: root

    readonly property string terminalsConfig: Plasmoid.configuration.terminals
    readonly property string title: {
        if (sessionsModel.count === 1) {
            let cmd = (sessionsModel.get(0).command || "/bin/bash").split("/").pop().split(" ")[0];
            return cmd || "Terminal";
        }
        return "Termibar";
    }

    ListModel {
        id: sessionsModel
    }

    property int activeSessionIndex: 0
    property int runningCount: 0

    preferredRepresentation: compactRepresentation
    hideOnWindowDeactivate: true

    toolTipMainText: title
    toolTipSubText: {
        if (runningCount === 0)
            return i18n("Click to launch");
        if (sessionsModel.count <= 1)
            return i18n("Running");
        return i18np("%1 session running", "%1 sessions running", runningCount);
    }

    Plasmoid.icon: Plasmoid.configuration.iconName || "utilities-terminal"

    readonly property int stateDead: 0
    readonly property int stateRunning: 1
    readonly property int stateBackgrounded: 2
    readonly property int stateExited: 3

    function buildConfigs() {
        let configs = [];
        let termList = Utils.parseTerminalList(Plasmoid.configuration.terminals);
        for (let i = 0; i < termList.length; i++) {
            configs.push({
                name: termList[i].name || "Terminal " + (i + 1),
                command: termList[i].command,
                workingDirectory: termList[i].workingDirectory || "",
                icon: termList[i].icon || "utilities-terminal",
                autoStart: termList[i].autoStart || false
            });
        }
        if (configs.length === 0) {
            configs.push({
                name: "Terminal",
                command: "/bin/bash",
                workingDirectory: "",
                icon: "utilities-terminal",
                autoStart: false
            });
        }
        return configs;
    }

    function initSessions() {
        sessionsModel.clear();
        let configs = buildConfigs();
        for (let i = 0; i < configs.length; i++) {
            sessionsModel.append({
                name: configs[i].name,
                command: configs[i].command,
                workingDirectory: configs[i].workingDirectory,
                icon: configs[i].icon,
                autoStart: configs[i].autoStart,
                sessionState: stateDead,
                exitCode: -1
            });
        }
        activeSessionIndex = 0;
        updateRunningCount();
    }

    function reconcileSessions() {
        let newConfigs = buildConfigs();

        for (let i = sessionsModel.count - 1; i >= 0; i--) {
            let existing = sessionsModel.get(i);
            let found = false;
            for (let j = 0; j < newConfigs.length; j++) {
                if (newConfigs[j].name === existing.name) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                let item = sessionsRepeater.itemAt(i);
                if (item)
                    item.shutdownKPart();
                sessionsModel.remove(i);
            }
        }

        for (let j = 0; j < newConfigs.length; j++) {
            let nc = newConfigs[j];
            let existingIndex = -1;
            for (let k = j; k < sessionsModel.count; k++) {
                if (sessionsModel.get(k).name === nc.name) {
                    existingIndex = k;
                    break;
                }
            }
            if (existingIndex === -1) {
                sessionsModel.append({
                    name: nc.name,
                    command: nc.command,
                    workingDirectory: nc.workingDirectory,
                    icon: nc.icon,
                    autoStart: nc.autoStart,
                    sessionState: stateDead,
                    exitCode: -1
                });
            } else {
                sessionsModel.setProperty(existingIndex, "icon", nc.icon);
                sessionsModel.setProperty(existingIndex, "workingDirectory", nc.workingDirectory);
                sessionsModel.setProperty(existingIndex, "autoStart", nc.autoStart);
                if (existingIndex !== j) {
                    sessionsModel.move(existingIndex, j, 1);
                }
            }
        }

        updateRunningCount();
        if (activeSessionIndex >= sessionsModel.count) {
            activeSessionIndex = Math.max(0, sessionsModel.count - 1);
        }
    }

    function updateRunningCount() {
        let count = 0;
        for (let i = 0; i < sessionsModel.count; i++) {
            let s = sessionsModel.get(i).sessionState;
            if (s === stateRunning || s === stateBackgrounded)
                count++;
        }
        runningCount = count;
    }

    function setSessionState(index, newState) {
        if (index < 0 || index >= sessionsModel.count)
            return;
        sessionsModel.setProperty(index, "sessionState", newState);
        updateRunningCount();
    }

    function launchSession(index) {
        setSessionState(index, stateRunning);
        activeSessionIndex = index;
        if (!expanded)
            expanded = true;
        if (typeof sessionsRepeater !== "undefined" && sessionsRepeater) {
            let item = sessionsRepeater.itemAt(index);
            if (item)
                item.startTerminal();
        }
    }

    Component.onCompleted: {
        initSessions();
        for (let i = 0; i < sessionsModel.count; i++) {
            if (sessionsModel.get(i).autoStart) {
                launchSession(i);
            }
        }
    }

    onTerminalsConfigChanged: reconcileSessions()

    onExpandedChanged: {
        if (expanded) {
            for (let i = 0; i < sessionsModel.count; i++) {
                if (sessionsModel.get(i).sessionState === stateBackgrounded) {
                    setSessionState(i, stateRunning);
                }
            }
        } else {
            for (let i = 0; i < sessionsModel.count; i++) {
                if (sessionsModel.get(i).sessionState === stateRunning) {
                    setSessionState(i, stateBackgrounded);
                }
            }
        }
    }

    compactRepresentation: MouseArea {
        id: compactRoot
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
            // TODO: restart active session
            {} else {
                root.expanded = !root.expanded;
            }
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactRoot.containsMouse
        }

        Rectangle {
            visible: root.runningCount > 0
            width: Kirigami.Units.smallSpacing * 2
            height: width
            radius: width / 2
            color: Kirigami.Theme.positiveTextColor
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
        }

        PlasmaComponents.Label {
            visible: sessionsModel.count > 1
            text: root.runningCount > 0 ? root.runningCount : ""
            font.pixelSize: Kirigami.Units.iconSizes.small * 0.6
            font.bold: true
            color: Kirigami.Theme.backgroundColor
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1

            background: Rectangle {
                visible: root.runningCount > 0
                color: Kirigami.Theme.highlightColor
                radius: height / 2
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: popupRoot

        Layout.preferredWidth: Kirigami.Units.gridUnit * Plasmoid.configuration.terminalColumns * 0.35
        Layout.preferredHeight: Kirigami.Units.gridUnit * Plasmoid.configuration.terminalRows * 0.75
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8

        function applyAnimationSetting() {
            if (!Plasmoid.configuration.disableAnimation)
                return;
            let win = popupRoot.Window.window;
            if (win && typeof win.animated !== "undefined") {
                win.animated = false;
            }
        }
        Component.onCompleted: {
            applyAnimationSetting();
            // Start any sessions that were autostarted before the popup existed
            for (let i = 0; i < sessionsModel.count; i++) {
                if (sessionsModel.get(i).sessionState === root.stateRunning) {
                    let item = sessionsRepeater.itemAt(i);
                    if (item)
                        item.startTerminal();
                }
            }
        }
        onWindowChanged: applyAnimationSetting()

        header: PlasmaExtras.PlasmoidHeading {
            visible: sessionsModel.count > 1
            height: visible ? implicitHeight : 0

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: sessionsModel

                    PlasmaComponents.TabButton {
                        Layout.fillWidth: true
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 8

                        checked: root.activeSessionIndex === index
                        text: model.name

                        onClicked: {
                            root.activeSessionIndex = index;
                        }

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle {
                                width: Kirigami.Units.smallSpacing * 1.5
                                height: width
                                radius: width / 2
                                color: {
                                    switch (model.sessionState) {
                                    case root.stateRunning:
                                    case root.stateBackgrounded:
                                        return Kirigami.Theme.positiveTextColor;
                                    case root.stateExited:
                                        return Kirigami.Theme.negativeTextColor;
                                    default:
                                        return Kirigami.Theme.disabledTextColor;
                                    }
                                }
                            }

                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: model.icon
                            }

                            PlasmaComponents.Label {
                                text: model.name
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        contentItem: StackLayout {
            id: terminalStack
            currentIndex: root.activeSessionIndex

            Repeater {
                id: sessionsRepeater
                model: sessionsModel

                TerminalSession {
                    isActive: root.activeSessionIndex === index
                    fontFamily: Plasmoid.configuration.fontFamily
                    fontSize: Plasmoid.configuration.fontSize

                    onExited: code => {
                        root.setSessionState(sessionIndex, root.stateExited);
                        sessionsModel.setProperty(sessionIndex, "exitCode", code);

                        if (Plasmoid.configuration.closeOnExit && sessionsModel.count <= 1) {
                            root.expanded = false;
                        }
                    }
                    onRestartRequested: {
                        root.launchSession(sessionIndex);
                    }
                }
            }
        }
    }
}
