set_target_properties(${PROJECT_NAME} PROPERTIES WIN32_EXECUTABLE TRUE)
target_compile_options(${PROJECT_NAME} PUBLIC /W4 /WX)

# Since PATH already includes QT_INSTALL_DIR/bin, we can find windeployqt without hints
find_program(WINDEPLOYQT_EXECUTABLE windeployqt)

if(NOT WINDEPLOYQT_EXECUTABLE)
    message(FATAL_ERROR "windeployqt not found")
endif()

# Generate the installation script using configure_file
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/post_install_windows.cmake.in"
    "${CMAKE_BINARY_DIR}/post_install_windows.cmake"
    @ONLY
)

# Install the post-install script to run after installation
install(SCRIPT "${CMAKE_BINARY_DIR}/post_install_windows.cmake")
