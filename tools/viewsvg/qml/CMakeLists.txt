file(
    GLOB_RECURSE SOURCES_QML
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    *.qml
)

qt_add_qml_module(
    ${PROJECT_NAME}_qml
    URI "qml"
    VERSION 1.0.0
    QML_FILES ${SOURCES_QML}
    RESOURCE_PREFIX "/qt/qml"
)
