import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes
import "utils.js" as Utils

KCM.SimpleKCM {
    id: configRoot

    property string cfg_terminals

    property var terminalList: []

    Component.onCompleted: {
        terminalList = Utils.parseTerminalList(cfg_terminals);
        if (terminalList.length === 0) {
            terminalList = [
                {
                    name: "Terminal",
                    command: "/bin/bash",
                    icon: "utilities-terminal",
                    autoStart: false
                }
            ];
            saveList();
        }
    }

    function saveList() {
        cfg_terminals = JSON.stringify(terminalList);
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Terminals")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: configRoot.terminalList

                Kirigami.AbstractCard {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: configRoot.terminalList[index].icon || "utilities-terminal"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QQC2.Label {
                                text: i18n("Name:")
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            }
                            QQC2.TextField {
                                Layout.fillWidth: true
                                text: modelData.name || ""
                                placeholderText: i18n("Terminal 1")
                                onTextEdited: {
                                    configRoot.terminalList[index].name = text;
                                    configRoot.saveList();
                                }
                            }

                            QQC2.Label {
                                text: i18n("Command:")
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            }

                            QQC2.TextField {
                                Layout.fillWidth: true
                                text: modelData.command || ""
                                placeholderText: "/bin/bash"
                                font.family: "Monospace"
                                onTextEdited: {
                                    configRoot.terminalList[index].command = text;
                                    configRoot.saveList();
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                QQC2.Label {
                                    text: i18n("Icon:")
                                }
                                QQC2.Button {
                                    icon.name: modelData.icon || "utilities-terminal"
                                    text: modelData.icon || "utilities-terminal"
                                    onClicked: {
                                        iconDialog.currentIndex = index;
                                        iconDialog.open();
                                    }
                                }
                            }

                            QQC2.CheckBox {
                                text: i18n("Autostart with panel")
                                checked: modelData.autoStart || false
                                onCheckedChanged: {
                                    configRoot.terminalList[index].autoStart = checked;
                                    configRoot.saveList();
                                }
                            }
                        }

                        QQC2.ToolButton {
                            icon.name: "edit-delete"
                            enabled: configRoot.terminalList.length > 1
                            onClicked: {
                                let list = configRoot.terminalList.slice();
                                list.splice(index, 1);
                                configRoot.terminalList = list;
                                configRoot.saveList();
                            }
                        }
                    }
                }
            }

            KIconThemes.IconDialog {
                id: iconDialog
                property int currentIndex: -1
                onIconNameChanged: function (iconName) {
                    if (currentIndex >= 0 && iconName) {
                        configRoot.terminalList[currentIndex].icon = iconName;
                        configRoot.saveList();
                    }
                }
            }

            QQC2.Button {
                text: i18n("Add Terminal")
                icon.name: "list-add"
                onClicked: {
                    let list = configRoot.terminalList.slice();
                    list.push({
                        name: "Terminal " + (list.length + 1),
                        command: i18n("e.g. /bin/bash, htop, spotify_player"),
                        icon: "utilities-terminal",
                        autoStart: false
                    });
                    configRoot.terminalList = list;
                    configRoot.saveList();
                }
            }
        }
    }
}
