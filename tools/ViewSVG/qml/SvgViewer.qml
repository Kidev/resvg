import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls
import QtQuick.Layouts
import ViewSVG.SvgViewer 1.0

Item {
    id: root

    property alias renderer: renderer

    // Public properties (interface)
    property alias source: renderer.source

    // Signals
    signal loadFailed(string error)

    // State management
    state: "empty"

    states: [
        State {
            name: "empty"
            when: !renderer.loading && renderer.source === ""
        },
        State {
            name: "loading"
            when: renderer.loading
        },
        State {
            name: "loaded"
            when: !renderer.loading && renderer.source !== ""
        }
    ]

    // Transitions between states
    transitions: [
        Transition {
            from: "*"
            to: "loading"

            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
                from: 0
                property: "opacity"
                target: loadingIndicator
                to: 1
            }
        },
        Transition {
            from: "loading"
            to: "*"

            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
                from: 1
                property: "opacity"
                target: loadingIndicator
                to: 0
            }
        }
    ]

    // SVG Renderer component (C++ backend)
    SvgRenderer {
        id: renderer

        anchors.fill: parent

        // Connect signals
        onLoadFailed: error => root.loadFailed(error)
        onLoadSucceeded: console.debug("SVG loaded successfully")
        onRenderFinished: console.debug("SVG rendering finished")
        onRenderStarted: console.debug("SVG rendering started")
    }

    // Empty state placeholder text
    Text {
        id: placeholderText

        anchors.centerIn: parent
        color: "#666666"
        opacity: root.state === "empty" ? 1.0 : 0.0
        text: "Drop an SVG image here"
        visible: root.state === "empty"

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }

        font {
            family: "Arial"
            pixelSize: 18
        }
    }

    // Loading indicator
    Item {
        id: loadingIndicator

        anchors.fill: parent
        opacity: root.state === "loading" ? 1.0 : 0.0
        visible: opacity > 0

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            opacity: 0.5
        }

        Column {
            anchors.centerIn: parent
            spacing: 16

            BusyIndicator {
                id: spinner

                anchors.horizontalCenter: parent.horizontalCenter
                height: 64
                running: root.state === "loading"
                width: 64
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "white"
                text: "Processing SVG..."

                font {
                    bold: true
                    pixelSize: 16
                }
            }
        }
    }

    // SVG info panel (visible when loaded)
    Rectangle {
        id: infoPanel

        color: "#80000000"
        height: 40
        opacity: visible ? 0.8 : 0
        visible: root.state === "loaded" && renderer.imageSize.width > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        RowLayout {
            spacing: 16

            anchors {
                fill: parent
                margins: 8
            }

            Label {
                color: "white"
                font.pixelSize: 12
                text: "Size: " + renderer.imageSize.width + "×" + renderer.imageSize.height
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                color: "white"
                font.pixelSize: 12
                text: renderer.fitToView ? "Fit to view" : "Original size"
            }
        }
    }

    // Drag and drop functionality integrated in the component
    DropArea {
        id: dropArea

        anchors.fill: parent

        onDropped: drop => {
            dropHighlight.visible = false;

            if (drop.hasUrls) {
                const url = drop.urls[0].toString();
                if (url.toLowerCase().endsWith(".svg") || url.toLowerCase().endsWith(".svgz")) {
                    renderer.source = url;
                } else {
                    // Signal error for invalid file type
                    root.loadFailed("Only SVG and SVGZ files are supported");
                }
            }
        }
        onEntered: drag => {
            drag.accept(Qt.CopyAction);
            dropHighlight.visible = true;
        }
        onExited: {
            dropHighlight.visible = false;
        }

        // Drop highlight overlay
        Rectangle {
            id: dropHighlight

            anchors.fill: parent
            color: "#4000A0FF"
            radius: 8
            visible: false

            border {
                color: "#0077CC"
                width: 4
            }

            Text {
                anchors.centerIn: parent
                color: "#0077CC"
                font.pixelSize: 24
                text: "Release to load SVG"
            }
        }
    }
}
