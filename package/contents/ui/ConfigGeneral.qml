import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    id: configRoot

    property alias cfg_terminalColumns: colsSpinbox.value
    property alias cfg_terminalRows: rowsSpinbox.value
    property alias cfg_closeOnExit: closeOnExitCheck.checked
    property alias cfg_disableAnimation: disableAnimCheck.checked
    property string cfg_iconName: "utilities-terminal"

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.Button {
            Kirigami.FormData.label: i18n("Panel icon:")
            icon.name: cfg_iconName || "utilities-terminal"
            text: cfg_iconName || "utilities-terminal"
            onClicked: iconDialog.open()
        }

        KIconThemes.IconDialog {
            id: iconDialog
            onIconNameChanged: function (iconName) {
                if (iconName) {
                    cfg_iconName = iconName;
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Terminal")
        }

        // These scale the popup only — the terminal's own rows/columns follow
        // the popup size, and its font comes from the Konsole profile.
        QQC2.SpinBox {
            id: colsSpinbox
            Kirigami.FormData.label: i18n("Popup width:")
            from: 40
            to: 300
        }

        QQC2.SpinBox {
            id: rowsSpinbox
            Kirigami.FormData.label: i18n("Popup height:")
            from: 10
            to: 100
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Behavior")
        }

        QQC2.CheckBox {
            id: closeOnExitCheck
            Kirigami.FormData.label: i18n("Close popup when process exits")
        }

        QQC2.CheckBox {
            id: disableAnimCheck
            Kirigami.FormData.label: i18n("Disable popup animation")
            text: i18n("Fix for terminal flicker on open/close")
        }
    }
}
