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

# Create a deploy script with improved error handling
file(GENERATE
    OUTPUT "${CMAKE_BINARY_DIR}/run_linuxdeploy.sh"
    CONTENT "#!/bin/bash
# Set up environment variables - explicitly use Qt6
export QMAKE=\"${_qmake_executable}\"
export QT_INSTALL_DIR=\"${QT_INSTALL_DIR}\"
export PATH=\"${QT_INSTALL_DIR}/bin:$PATH\"
export LD_LIBRARY_PATH=\"${QT_INSTALL_DIR}/lib:$LD_LIBRARY_PATH\"
export QML_SOURCES_PATHS=\"${QML_SOURCES_PATHS}\"
export OUTPUT=\"${PROJECT_NAME}-x86_64.AppImage\"
# Disable stripping to avoid errors with newer library formats
export NO_STRIP=1

echo \"Using Qt6 from: ${QT_INSTALL_DIR}\"
echo \"Using qmake: ${QMAKE}\"

# First copy the Qt plugin to the expected location
mkdir -p ${CMAKE_BINARY_DIR}/plugins
cp ${LINUXDEPLOY_QT_DOWNLOAD} ${CMAKE_BINARY_DIR}/plugins/linuxdeploy-plugin-qt
chmod +x ${CMAKE_BINARY_DIR}/plugins/linuxdeploy-plugin-qt

# Create a .desktop file in the AppDir with the correct name
cat > ${APPDIR}/usr/share/applications/${PROJECT_NAME}.desktop << EOF
[Desktop Entry]
Type=Application
Name=ViewSVG
Comment=Simple SVG viewer
Exec=${PROJECT_NAME}
Icon=${PROJECT_NAME}
Categories=Graphics;Viewer;Qt;
EOF

# Run linuxdeploy but redirect all error output to a log file
${LINUXDEPLOY_DOWNLOAD} --appdir=${APPDIR} --plugin=qt --output=appimage 2> linuxdeploy-errors.log
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo \"WARNING: linuxdeploy exited with code $exit_code.\"
    echo \"Trying direct deployment...\"

    # Create an AppRun script
    cat > ${APPDIR}/AppRun << EOF
#!/bin/bash
HERE=\"\$(dirname \"\$(readlink -f \"\${0}\")\")\"
export LD_LIBRARY_PATH=\"\${HERE}/usr/lib:\${LD_LIBRARY_PATH}\"
export QML_IMPORT_PATH=\"\${HERE}/usr/qml\"
export QML2_IMPORT_PATH=\"\${HERE}/usr/qml\"
export QT_PLUGIN_PATH=\"\${HERE}/usr/plugins\"
export QT_QPA_PLATFORM_PLUGIN_PATH=\"\${HERE}/usr/plugins/platforms\"
exec \"\${HERE}/usr/bin/${PROJECT_NAME}\" \"\$@\"
EOF
    chmod +x ${APPDIR}/AppRun

    # Create symlinks for the icon
    mkdir -p ${APPDIR}/usr/share/icons/hicolor/scalable/apps/
    ln -sf ${APPDIR}/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png ${APPDIR}/usr/share/icons/hicolor/scalable/apps/${PROJECT_NAME}.png
    ln -sf ${APPDIR}/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png ${APPDIR}/${PROJECT_NAME}.png

    # Manually copy Qt plugins
    echo \"Copying Qt plugins...\"
    mkdir -p ${APPDIR}/usr/plugins
    mkdir -p ${APPDIR}/usr/plugins/platforms
    mkdir -p ${APPDIR}/usr/plugins/imageformats
    mkdir -p ${APPDIR}/usr/plugins/iconengines
    cp -r ${QT_INSTALL_DIR}/plugins/platforms/libqxcb.so ${APPDIR}/usr/plugins/platforms/
    cp -r ${QT_INSTALL_DIR}/plugins/imageformats/libqsvg.so ${APPDIR}/usr/plugins/imageformats/
    cp -r ${QT_INSTALL_DIR}/plugins/iconengines/libqsvgicon.so ${APPDIR}/usr/plugins/iconengines/

    # Copy QML modules
    echo \"Copying QML modules...\"
    mkdir -p ${APPDIR}/usr/qml
    cp -r ${QT_INSTALL_DIR}/qml/QtQuick ${APPDIR}/usr/qml/
    cp -r ${QT_INSTALL_DIR}/qml/QtQuick.2 ${APPDIR}/usr/qml/
    cp -r ${QT_INSTALL_DIR}/qml/QtQml ${APPDIR}/usr/qml/

    # Download appimagetool if needed
    if [ ! -f \"appimagetool-x86_64.AppImage\" ]; then
        echo \"Downloading appimagetool...\"
        wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
        chmod +x appimagetool-x86_64.AppImage
    fi

    # Try creating the AppImage with appimagetool
    echo \"Creating AppImage with appimagetool...\"
    ./appimagetool-x86_64.AppImage ${APPDIR} ${PROJECT_NAME}-x86_64.AppImage 2>> linuxdeploy-errors.log
fi

# Check if AppImage was created
if [ -f \"${PROJECT_NAME}-x86_64.AppImage\" ]; then
    echo \"AppImage created successfully: ${PROJECT_NAME}-x86_64.AppImage\"
    chmod +x ${PROJECT_NAME}-x86_64.AppImage
else
    echo \"WARNING: AppImage creation failed. See linuxdeploy-errors.log for details\"
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
