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

    required property int index
    readonly property int sessionIndex: index
    required property bool isActive

    signal exited
    signal restartRequested

    // 0=Dead, 1=Running, 2=Backgrounded, 3=Exited
    readonly property int currentState: sessionState

    // An autostarted session is already Running when its delegate is built, so
    // the initial 0->1 binding evaluation fires onCurrentStateChanged mid-creation
    // — before terminalItem's command binding has been evaluated. Starting there
    // would hand KonsoleItem an empty command and launch a bare shell, and since
    // start() is idempotent the correct call afterwards would do nothing. Wait for
    // completion, which is the point where all bindings are in place.
    property bool bindingsReady: false

    Component.onCompleted: {
        bindingsReady = true;
        if (currentState === 1)
            terminalItem.start();
    }

    onCurrentStateChanged: {
        if (bindingsReady && currentState === 1)
            terminalItem.start();
    }

    function shutdownKPart() {
        terminalItem.shutdown();
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
                text: command || i18n("Default shell")
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

        onExited: sessionRoot.exited()
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
                    // KonsolePart reports no exit status — it just goes away when
                    // the session ends — so there is no code to show here.
                    text: i18n("Process exited")
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
