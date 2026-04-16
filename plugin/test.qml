import QtQuick
import QtQuick.Window
import org.termibar

Window {
    id: root
    width: 800
    height: 500
    visible: true
    title: "Termibar KPart Spike"
    color: "black"

    KonsoleItem {
        id: terminal
        anchors.fill: parent
        command: "/bin/bash"
        focus: true

        Component.onCompleted: {
            terminal.start()
            terminal.forceActiveFocus()
        }

        onExited: (code) => {
            console.log("Terminal exited with code:", code)
            Qt.quit()
        }
    }

    Text {
        anchors.centerIn: parent
        text: "Loading konsolepart..."
        color: "#666"
        font.pixelSize: 14
        visible: !terminal.visible
    }
}
