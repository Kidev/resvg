import QtQuick
import QtQuick.Window
import QtQuick.Controls.Material
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform as Platform
import SvgViewer 1.0

ApplicationWindow {
    id: window

    Material.accent: Material.Blue
    Material.primary: Material.Indigo

    // Material design theme
    Material.theme: Material.Light
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
                        return "Ready - Drop an SVG file to view";
                    case "loading":
                        return "Loading SVG...";
                    case "loaded":
                        return "SVG loaded - " + svgViewer.source.toString().split('/').pop();
                    default:
                        return "Ready";
                    }
                }
            }
        }
    }

    // Top toolbar with Material design
    header: ToolBar {
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
                    text: "Size:"
                }

                ComboBox {
                    id: sizeComboBox

                    Material.background: Material.LightGrey

                    // Material styling
                    Material.foreground: Material.Grey
                    currentIndex: 1
                    model: ["Original", "Fit to View"]

                    onCurrentIndexChanged: svgViewer.renderer.fitToView = currentIndex === 1
                }
            }

            RowLayout {
                spacing: 8

                Label {
                    color: "white"
                    text: "Background:"
                }

                ComboBox {
                    id: backgroundComboBox

                    Material.background: Material.LightGrey

                    // Material styling
                    Material.foreground: Material.Grey
                    currentIndex: 1
                    model: ["None", "White", "Check board"]

                    onCurrentIndexChanged: svgViewer.renderer.background = currentIndex
                }
            }

            CheckBox {
                id: borderCheckBox

                // Material styling
                Material.accent: Material.LightBlue
                text: "Draw border"

                contentItem: Text {
                    color: "white"
                    font: borderCheckBox.font
                    leftPadding: borderCheckBox.indicator.width + 4
                    text: borderCheckBox.text
                    verticalAlignment: Text.AlignVCenter
                }

                onCheckedChanged: svgViewer.renderer.drawImageBorder = checked
            }

            Item {
                Layout.fillWidth: true
            } // Spacer



            // SVG information display
            Label {
                id: infoLabel

                color: "white"
                font.pixelSize: 12
                text: {
                    if (svgViewer.state !== "loaded" || !svgViewer.renderer.imageSize)
                        return "";

                    return `SVG: ${svgViewer.renderer.imageSize.width}×${svgViewer.renderer.imageSize.height}`;
                }
                visible: svgViewer.state === "loaded"
            }

            Button {

                // Material styling
                Material.accent: Material.LightBlue
                Material.background: Material.Blue
                Material.foreground: "white"
                highlighted: true
                text: "Open SVG"

                onClicked: fileDialog.open()
            }
        }
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
        width: Math.min(window.width - 50, 400)

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
        onLoadFailed: error => {
            errorDialog.errorMessage = error;
            errorDialog.open();
        }
    }
}
