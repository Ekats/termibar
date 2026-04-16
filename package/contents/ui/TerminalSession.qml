import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.termibar 1.0

Item {
    id: sessionRoot

    // Role-based properties from sessionsModel — resolved automatically by
    // the Repeater against ListModel role names.
    required property string name
    required property string command
    required property string workingDirectory
    required property string icon
    required property int sessionState
    required property int exitCode

    required property int index
    readonly property int sessionIndex: index
    required property bool isActive
    property string fontFamily: "Monospace"
    property int fontSize: 10

    signal exited(int code)
    signal restartRequested

    // 0=Dead, 1=Running, 2=Backgrounded, 3=Exited
    readonly property int currentState: sessionState

    onCurrentStateChanged: {
        if (currentState === 1)
            terminalItem.start();
    }

    function shutdownKPart() {
        terminalItem.shutdown();
    }

    function startTerminal(cmd) {
        if (cmd)
            terminalItem.command = cmd;
        terminalItem.start();
    }

    // Covers both config-driven removal and plasmoid unload.
    Component.onDestruction: shutdownKPart()

    // --- Dead: launch prompt ---
    Item {
        anchors.fill: parent
        visible: currentState === 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                source: icon || "utilities-terminal"
                opacity: 0.5
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: command
                font.family: sessionRoot.fontFamily
                opacity: 0.7
            }

            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                text: i18n("Launch")
                icon.name: "media-playback-start"
                onClicked: {
                    console.log("LAUNCH CLICKED, sessionIndex:", sessionRoot.sessionIndex, "currentState:", sessionRoot.currentState);
                    sessionRoot.restartRequested();
                }
            }
        }
    }

    // --- Running/Backgrounded: Konsole KPart ---
    KonsoleItem {
        id: terminalItem
        anchors.fill: parent
        visible: currentState === 1 || currentState === 2
        command: sessionRoot.command || "/bin/bash"
        workingDirectory: sessionRoot.workingDirectory || ""

        onExited: code => sessionRoot.exited(code)
    }

    // --- Exited: exit info + restart ---
    Item {
        anchors.fill: parent
        visible: currentState === 3

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.largeSpacing

            Item {
                Layout.fillHeight: true
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    source: "process-stop"
                }

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        let code = exitCode;
                        if (code === 0)
                            return i18n("Process exited normally");
                        if (code > 0)
                            return i18n("Process exited with code %1", code);
                        return i18n("Process terminated");
                    }
                }

                PlasmaComponents.Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: i18n("Restart")
                    icon.name: "view-refresh"
                    onClicked: {
                        console.log("LAUNCH CLICKED, sessionIndex:", sessionRoot.sessionIndex, "currentState:", sessionRoot.currentState);
                        sessionRoot.restartRequested();
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
