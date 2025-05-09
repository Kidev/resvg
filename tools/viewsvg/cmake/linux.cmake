target_compile_options(${PROJECT_NAME} PUBLIC -Wall -Werror -Wpedantic)

# Set AppDir path
set(APPDIR "${CMAKE_BINARY_DIR}/AppDir")

# Download linuxdeploy and Qt plugin
set(LINUXDEPLOY_URL "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage")
set(LINUXDEPLOY_DOWNLOAD "${CMAKE_BINARY_DIR}/linuxdeploy-x86_64.AppImage")
set(LINUXDEPLOY_QT_URL "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage")
set(LINUXDEPLOY_QT_DOWNLOAD "${CMAKE_BINARY_DIR}/linuxdeploy-plugin-qt-x86_64.AppImage")

# Download the AppImages if not already present
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

# Create AppDir directory structure
add_custom_command(
    TARGET ${PROJECT_NAME}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${APPDIR}/usr/bin
    COMMAND ${CMAKE_COMMAND} -E make_directory ${APPDIR}/usr/share/applications
    COMMAND ${CMAKE_COMMAND} -E make_directory ${APPDIR}/usr/share/icons/hicolor/256x256/apps
)

# Copy executable to AppDir
add_custom_command(
    TARGET ${PROJECT_NAME}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${PROJECT_NAME}> ${APPDIR}/usr/bin/
)

# Create .desktop file
file(GENERATE
    OUTPUT "${APPDIR}/usr/share/applications/${PROJECT_NAME}.desktop"
    CONTENT "[Desktop Entry]
Type=Application
Name=ViewSVG
Comment=Simple SVG viewer
Exec=${PROJECT_NAME}
Icon=${PROJECT_NAME}
Categories=Graphics;Viewer;Qt;
"
)

# Copy icon
add_custom_command(
    TARGET ${PROJECT_NAME}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${CMAKE_SOURCE_DIR}/viewsvg.png
            ${APPDIR}/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png
    COMMENT "Copying application icon..."
)

# Get Qt bin dir for deployment
get_target_property(_qmake_executable Qt6::qmake IMPORTED_LOCATION)
get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)

# Create a deploy script
file(GENERATE
    OUTPUT "${CMAKE_BINARY_DIR}/run_linuxdeploy.sh"
    CONTENT "#!/bin/bash
# Set up environment variables
export PATH=\"${_qt_bin_dir}:$PATH\"
export LD_LIBRARY_PATH=\"${APPDIR}/usr/lib:$LD_LIBRARY_PATH\"
export QML_SOURCES_PATHS=\"${CMAKE_SOURCE_DIR}/qml\"
export OUTPUT=\"${PROJECT_NAME}-x86_64.AppImage\"

# First copy the Qt plugin to the expected location
mkdir -p ${CMAKE_BINARY_DIR}/plugins
cp ${LINUXDEPLOY_QT_DOWNLOAD} ${CMAKE_BINARY_DIR}/plugins/linuxdeploy-plugin-qt
chmod +x ${CMAKE_BINARY_DIR}/plugins/linuxdeploy-plugin-qt

# Run linuxdeploy
${LINUXDEPLOY_DOWNLOAD} --appdir=${APPDIR} --plugin=qt --output=appimage
exit_code=$?

if [ $exit_code -ne 0 ]; then
echo \"WARNING: AppImage creation failed with exit code $exit_code\"
echo \"The basic AppDir structure is available at: ${APPDIR}\"
echo \"You can try running linuxdeploy manually for debugging.\"
fi

# Always exit with success so the build continues
exit 0
"
)

# Make script executable and run it
add_custom_command(
    TARGET ${PROJECT_NAME}
    POST_BUILD
    COMMAND chmod +x "${CMAKE_BINARY_DIR}/run_linuxdeploy.sh"
    COMMAND "${CMAKE_BINARY_DIR}/run_linuxdeploy.sh"
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running linuxdeploy to create AppImage..."
)
