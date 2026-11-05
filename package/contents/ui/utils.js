function parseTerminalList(raw) {
    if (!raw) return []
    try {
        let parsed = JSON.parse(raw)
        if (!Array.isArray(parsed)) return []
        return parsed.filter(function(entry) {
            // An empty command is valid and means "just a shell" — KonsoleItem
            // starts the default one. Dropping those entries would silently
            // delete a terminal whose command the user cleared.
            return entry && typeof entry === "object"
        })
    } catch (e) {
        console.warn("Termibar: corrupted terminals config, resetting:", e)
        return []
    }
}

// The KonsoleItem plugin is installed separately by install.sh, so a plasmoid
// bundle on its own does not carry it. TerminalSession.qml imports it and would
// fail to compile, leaving a blank popup with only a log line to explain it —
// check here so the popup can say what is wrong instead.
function hasTerminalPlugin(parent) {
    try {
        let probe = Qt.createQmlObject("import QtQuick\nimport org.termibar 1.0\nQtObject {}", parent)
        if (probe)
            probe.destroy()
        return true
    } catch (e) {
        return false
    }
}
