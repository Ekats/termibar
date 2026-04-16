import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "utilities-terminal"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Terminals")
        icon: "tab-duplicate"
        source: "ConfigTerminals.qml"
    }
}
