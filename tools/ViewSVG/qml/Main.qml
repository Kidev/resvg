import QtQuick
import QtQuick.Window
import QtQuick.Controls.Material
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root

    Material.accent: "#E4B000"
    Material.background: "#121212"
    Material.containerStyle: Material.Filled
    Material.elevation: 2
    Material.foreground: "#FFFFFF"
    Material.primary: "#1E2A78"
    Material.roundedScale: Material.MediumScale
    Material.theme: Material.Dark

    // Material design theme
    height: 700
    title: "ViewSVG"
    visible: true
    width: 900

    // Status bar
    footer: Rectangle {
        color: Material.primary
        height: 28
        width: parent.width

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
            }

            Label {
                Layout.fillWidth: true
                color: "white"
                elide: Text.ElideMiddle
                font.pixelSize: 12
                text: {
                    switch (svgViewer.state) {
                    case "empty":
                        return "Ready";
                    case "loading":
                        return "Loading SVG...";
                    case "loaded":
                        return "SVG loaded - " + svgViewer.source.toString().split('/').pop();
                    default:
                        return "Ready";
                    }
                }
            }

            Label {
                color: "white"
                font.pixelSize: 12
                text: "Size: " + svgViewer.renderer.imageSize.width + "×" + svgViewer.renderer.imageSize.height
                visible: svgViewer.state === "loaded"
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                color: "white"
                font.pixelSize: 12
                text: svgViewer.renderer.fitToView ? "(Fit to view)" : "(Original size)"
                visible: svgViewer.state === "loaded"
            }
        }
    }

    // Top toolbar with Material design
    header: ToolBar {
        Layout.fillWidth: true
        Material.foreground: "white"
        height: 56

        RowLayout {
            spacing: 16

            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
            }

            RowLayout {
                spacing: 8

                Label {
                    color: "white"
                    font.bold: true
                    text: "Size:"
                }

                ComboBox {
                    id: sizeComboBox

                    Layout.minimumWidth: 175
                    Layout.preferredHeight: 40
                    Material.background: Material.BlueGrey
                    Material.foreground: "#FFFFFF"
                    currentIndex: 1
                    model: ["Original", "Fit to View"]

                    onCurrentIndexChanged: svgViewer.renderer.fitToView = currentIndex === 1
                }
            }

            RowLayout {
                spacing: 8

                Label {
                    color: "white"
                    font.bold: true
                    text: "Background:"
                }

                ComboBox {
                    id: backgroundComboBox

                    Layout.minimumWidth: 175
                    Layout.preferredHeight: 40
                    Material.background: Material.BlueGrey
                    Material.foreground: "#FFFFFF"
                    currentIndex: 2
                    model: ["None", "White", "Check board"]

                    onCurrentIndexChanged: svgViewer.renderer.background = currentIndex
                }
            }

            CheckBox {
                id: borderCheckBox

                font.bold: true
                text: "Draw border"

                onCheckedChanged: svgViewer.renderer.drawImageBorder = checked
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                id: openSvgButton

                Layout.minimumHeight: 50
                font.bold: true
                text: "Open SVG"

                background: Rectangle {
                    border.color: openSvgButton.hovered ? "#FFFFFF" : Material.accent
                    border.width: 2
                    color: "transparent"
                    radius: 8

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
                contentItem: Text {
                    anchors.fill: parent
                    color: openSvgButton.hovered ? "#FFFFFF" : Material.accent
                    font: openSvgButton.font
                    horizontalAlignment: Text.AlignHCenter
                    text: openSvgButton.text
                    verticalAlignment: Text.AlignVCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                onClicked: fileDialog.open()
            }
        }
    }

    Shortcut {
        sequence: "Esc"

        onActivated: Qt.exit(0)
    }

    // File dialog for opening SVG files
    FileDialog {
        id: fileDialog

        nameFilters: ["SVG files (*.svg *.svgz)"]
        title: "Open SVG File"

        onAccepted: svgViewer.source = fileDialog.selectedFile
    }

    // Error dialog
    Dialog {
        id: errorDialog

        property string errorMessage: ""

        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok
        title: "Error"
        width: Math.min(root.width - 50, 400)

        contentItem: Label {
            padding: 20
            text: errorDialog.errorMessage
            wrapMode: Text.WordWrap
        }
    }

    // Main content area with SVG viewer
    SvgViewer {
        id: svgViewer

        anchors.fill: parent

        // Load initial file if provided via command line
        Component.onCompleted: {
            if (initialFilePath !== "") {
                svgViewer.source = "file:///" + initialFilePath;
            }
        }

        // Connect signals
        onLoadFailed: function (error) {
            errorDialog.errorMessage = error;
            errorDialog.open();
        }
    }
}
