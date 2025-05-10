set_target_properties(${PROJECT_NAME} PROPERTIES MACOSX_BUNDLE TRUE)
target_compile_options(${PROJECT_NAME} PUBLIC -Wall -Werror -Wpedantic)

# Since PATH already includes QT_INSTALL_DIR/bin, we can find macdeployqt without hints
find_program(MACDEPLOYQT_EXECUTABLE macdeployqt)

if(NOT MACDEPLOYQT_EXECUTABLE)
    message(FATAL_ERROR "macdeployqt not found")
endif()

# Get the project binary directory for configure_file
set(PROJECT_BINARY_DIR "${CMAKE_BINARY_DIR}")

# Generate the installation script using configure_file
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/post_install_macos.cmake.in"
    "${CMAKE_BINARY_DIR}/post_install_macos.cmake"
    @ONLY
)

# Install the post-install script to run after installation
install(SCRIPT "${CMAKE_BINARY_DIR}/post_install_macos.cmake")

# Debug: Output where the app is being installed
message(STATUS "CMAKE_INSTALL_BINDIR=${CMAKE_INSTALL_BINDIR}")
message(STATUS "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}")
