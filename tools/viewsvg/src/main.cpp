// Copyright 2025 the Resvg Authors
// SPDX-License-Identifier: Apache-2.0 OR MIT

#include "svgrenderer.hpp"
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[])
{
    QGuiApplication app{argc, argv};

    // Set application info
    app.setApplicationName("ViewSVG");
    app.setApplicationVersion(QStringLiteral(VERSION_TAG));

    // Parse command line arguments
    QCommandLineParser parser;
    parser.setApplicationDescription("SVG Viewer application");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument("file", "SVG file to open (optional)", "[file]");

    parser.process(app);

    QQmlApplicationEngine engine;

    // Get initial file path if provided
    QString initialFilePath;
    const QStringList args{parser.positionalArguments()};
    if (!args.isEmpty()) {
        initialFilePath = args.first();
    }

    // Set initial file path as context property
    engine.rootContext()->setContextProperty("initialFilePath", initialFilePath);

    qmlRegisterType<SvgRenderer>("SvgViewer", 1, 0, "SvgRenderer");

    // Load main QML file
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("qml", "Main");

    return app.exec();
}
