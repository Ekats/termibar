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
    // Resolved once in Component.onCompleted; see Utils.hasTerminalPlugin.
    property bool pluginAvailable: true

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
            let name = termList[i].name || "Terminal " + (i + 1);
            configs.push({
                // Identity used by reconcileSessions. Entries written before ids
                // existed fall back to their name, i.e. the previous behaviour.
                key: termList[i].id ? "id:" + termList[i].id : "name:" + name,
                name: name,
                // Empty means "just a shell"; the role must stay a string so the
                // delegate's required property resolves.
                command: typeof termList[i].command === "string" ? termList[i].command : "",
                workingDirectory: termList[i].workingDirectory || "",
                icon: termList[i].icon || "utilities-terminal",
                autoStart: termList[i].autoStart || false
            });
        }
        if (configs.length === 0) {
            configs.push({
                key: "name:Terminal",
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
                key: configs[i].key,
                name: configs[i].name,
                command: configs[i].command,
                workingDirectory: configs[i].workingDirectory,
                icon: configs[i].icon,
                autoStart: configs[i].autoStart,
                sessionState: stateDead
            });
        }
        activeSessionIndex = 0;
        updateRunningCount();
    }

    function reconcileSessions() {
        let newConfigs = buildConfigs();

        // Sessions started before their config entry had an id are keyed by name.
        // Re-key them so the one-time id migration adopts the running process
        // instead of dropping it below. Removable once no pre-id configs remain.
        for (let j = 0; j < newConfigs.length; j++) {
            if (newConfigs[j].key.indexOf("id:") !== 0)
                continue;
            for (let k = 0; k < sessionsModel.count; k++) {
                if (sessionsModel.get(k).key === "name:" + newConfigs[j].name) {
                    sessionsModel.setProperty(k, "key", newConfigs[j].key);
                    break;
                }
            }
        }

        for (let i = sessionsModel.count - 1; i >= 0; i--) {
            let existing = sessionsModel.get(i);
            let found = false;
            for (let j = 0; j < newConfigs.length; j++) {
                if (newConfigs[j].key === existing.key) {
                    found = true;
                    break;
                }
            }
            // Removing the row destroys the delegate, and TerminalSession's
            // Component.onDestruction shuts its KPart down.
            if (!found)
                sessionsModel.remove(i);
        }

        for (let j = 0; j < newConfigs.length; j++) {
            let nc = newConfigs[j];
            let existingIndex = -1;
            for (let k = j; k < sessionsModel.count; k++) {
                if (sessionsModel.get(k).key === nc.key) {
                    existingIndex = k;
                    break;
                }
            }
            if (existingIndex === -1) {
                sessionsModel.append({
                    key: nc.key,
                    name: nc.name,
                    command: nc.command,
                    workingDirectory: nc.workingDirectory,
                    icon: nc.icon,
                    autoStart: nc.autoStart,
                    sessionState: stateDead
                });
            } else {
                // A command edit lands in the model but does not kill a running
                // process — it takes effect on the next start.
                sessionsModel.setProperty(existingIndex, "name", nc.name);
                sessionsModel.setProperty(existingIndex, "command", nc.command);
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
        // Setting the state to Running is what starts the KPart: TerminalSession
        // reacts to it. The delegate itself is unreachable from here — its
        // Repeater id lives in the fullRepresentation component scope — and when
        // the popup does not exist yet, its Component.onCompleted picks the
        // session up instead.
        setSessionState(index, stateRunning);
        activeSessionIndex = index;
        if (!expanded)
            expanded = true;
    }

    Component.onCompleted: {
        pluginAvailable = Utils.hasTerminalPlugin(root);
        initSessions();
        if (!pluginAvailable) {
            console.warn("Termibar: org.termibar plugin not found — run install.sh");
            return;
        }
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

        readonly property int configuredWidth: Math.round(Kirigami.Units.gridUnit * Plasmoid.configuration.terminalColumns * 0.35)
        readonly property int configuredHeight: Math.round(Kirigami.Units.gridUnit * Plasmoid.configuration.terminalRows * 0.75)

        // Only used for the very first open of a fresh widget; after that Plasma
        // has a saved size and ignores these (see applyPopupSize).
        Layout.preferredWidth: popupRoot.configuredWidth
        Layout.preferredHeight: popupRoot.configuredHeight
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

        // AppletPopup writes popupWidth/popupHeight into the applet config on
        // every hide, and once such a size exists its updateSize() returns early
        // and never looks at Layout.preferredWidth/Height again. So the configured
        // size has to be pushed onto the popup window itself, on every open.
        // Consequence: dragging the popup edge works but is not remembered.
        function applyPopupSize() {
            let win = popupRoot.Window.window;
            if (!win)
                return;
            win.width = popupRoot.configuredWidth;
            win.height = popupRoot.configuredHeight;
        }

        // Sessions autostarted before the popup existed start themselves: each
        // TerminalSession checks its state once its own bindings are ready.
        Component.onCompleted: {
            applyAnimationSetting();
            applyPopupSize();
        }
        onWindowChanged: {
            applyAnimationSetting();
            applyPopupSize();
        }
        onConfiguredWidthChanged: applyPopupSize()
        onConfiguredHeightChanged: applyPopupSize()

        // The popup window outlives a single open/close cycle, so the handlers
        // above only ever fire once. Plasma restores its saved size on each show
        // (including a size the user dragged to), which is why the configured
        // size has to be re-applied every time the popup becomes visible.
        Connections {
            target: popupRoot.Window.window
            function onVisibleChanged(visible) {
                if (visible)
                    popupRoot.applyPopupSize();
            }
        }

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

        // Without the native plugin TerminalSession.qml cannot even compile, so
        // it must not be instantiated at all in that case.
        contentItem: Loader {
            sourceComponent: root.pluginAvailable ? sessionsView : missingPluginView
        }

        Component {
            id: sessionsView

            StackLayout {
                id: terminalStack
                currentIndex: root.activeSessionIndex

                Repeater {
                    id: sessionsRepeater
                    model: sessionsModel

                    TerminalSession {
                        isActive: root.activeSessionIndex === index

                        onExited: {
                            root.setSessionState(sessionIndex, root.stateExited);

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

        Component {
            id: missingPluginView

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                Item { Layout.fillHeight: true }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    source: "dialog-error"
                }

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: i18n("Terminal plugin not found")
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.gridUnit
                    Layout.rightMargin: Kirigami.Units.gridUnit
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                    text: i18n("Termibar needs its native QML plugin, which is not part of the widget package. Run install.sh from the Termibar source to build and install it.")
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
