function parseTerminalList(raw) {
    if (!raw) return []
    try {
        let parsed = JSON.parse(raw)
        if (!Array.isArray(parsed)) return []
        return parsed.filter(function(entry) {
            return entry
                && typeof entry === "object"
                && typeof entry.command === "string"
                && entry.command.length > 0
        })
    } catch (e) {
        console.warn("Termibar: corrupted terminals config, resetting:", e)
        return []
    }
}
