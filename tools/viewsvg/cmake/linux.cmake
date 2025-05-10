target_compile_options(${PROJECT_NAME} PUBLIC -Wall -Werror -Wpedantic)

# Set AppDir path
set(APPDIR "${CMAKE_BINARY_DIR}/AppDir")

# Download linuxdeploy and Qt plugin
set(LINUXDEPLOY_URL "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage")
set(LINUXDEPLOY_DOWNLOAD "${CMAKE_BINARY_DIR}/linuxdeploy-x86_64.AppImage")
set(LINUXDEPLOY_QT_URL "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage")
set(LINUXDEPLOY_QT_DOWNLOAD "${CMAKE_BINARY_DIR}/linuxdeploy-plugin-qt-x86_64.AppImage")

# Download the AppImages if not already present during configuration
if(NOT EXISTS ${LINUXDEPLOY_DOWNLOAD})
    message(STATUS "Downloading linuxdeploy...")
    file(DOWNLOAD ${LINUXDEPLOY_URL} ${LINUXDEPLOY_DOWNLOAD} SHOW_PROGRESS)
    execute_process(COMMAND chmod a+x ${LINUXDEPLOY_DOWNLOAD})
endif()

if(NOT EXISTS ${LINUXDEPLOY_QT_DOWNLOAD})
    message(STATUS "Downloading linuxdeploy-plugin-qt...")
    file(DOWNLOAD ${LINUXDEPLOY_QT_URL} ${LINUXDEPLOY_QT_DOWNLOAD} SHOW_PROGRESS)
    execute_process(COMMAND chmod a+x ${LINUXDEPLOY_QT_DOWNLOAD})
endif()

# Generate the post-install CMake script using configure_file
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/post_install_linux.cmake.in"
    "${CMAKE_BINARY_DIR}/post_install_linux.cmake"
    @ONLY
)

# Generate the deployment script using configure_file
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/run_linuxdeploy.sh.in"
    "${CMAKE_BINARY_DIR}/run_linuxdeploy.sh"
    @ONLY
)

# Generate the desktop file template
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/application.desktop.in"
    "${CMAKE_BINARY_DIR}/application.desktop"
    @ONLY
)

# Install the post-install script to run after installation
# Set the CMAKE_INSTALL_PREFIX as a script variable
set(CMAKE_INSTALL_PREFIX ${CMAKE_INSTALL_PREFIX})
install(SCRIPT "${CMAKE_BINARY_DIR}/post_install_linux.cmake")
