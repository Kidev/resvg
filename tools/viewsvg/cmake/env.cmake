get_target_property(_qmake_executable Qt6::qmake IMPORTED_LOCATION)
get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)
cmake_path(GET _qt_bin_dir PARENT_PATH _qt_root_dir)

resolve_env_or_var(QT_ROOT_DIR ${_qt_root_dir} QT_INSTALL_DIR)
resolve_env_or_var(QT_QML_SOURCES "${CMAKE_SOURCE_DIR}/qml" QML_SOURCES_PATHS)

# Make sure to set these in CMAKE_ENVIRONMENT_PATH_INSTALL to influence Qt's tools
set(CMAKE_ENVIRONMENT_PATH_INSTALL "${QT_INSTALL_DIR}/bin")
set(QT_QMAKE_EXECUTABLE "${_qmake_executable}")
set(QT_INSTALL_QML "${QT_INSTALL_DIR}/qml")
set(QT_INSTALL_PLUGINS "${QT_INSTALL_DIR}/plugins")

# Set Qt paths as environment variables
append_env_path(QT_PLUGIN_PATH "${QT_INSTALL_DIR}/plugins")
append_env_path(QML2_IMPORT_PATH "${QT_INSTALL_DIR}/qml")
prepend_env_path(LD_LIBRARY_PATH "${QT_INSTALL_DIR}/lib")
prepend_env_path(PATH "${QT_INSTALL_DIR}/bin")

message(STATUS "QT_INSTALL_DIR=${QT_INSTALL_DIR}")
message(STATUS "QML_SOURCES_PATHS=${QML_SOURCES_PATHS}")
message(STATUS "QT_PLUGIN_PATH=$ENV{QT_PLUGIN_PATH}")
message(STATUS "QML2_IMPORT_PATH=$ENV{QML2_IMPORT_PATH}")
message(STATUS "LD_LIBRARY_PATH=$ENV{LD_LIBRARY_PATH}")
message(STATUS "PATH=$ENV{PATH}")
