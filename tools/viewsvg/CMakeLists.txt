cmake_minimum_required(VERSION 3.22)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/functions.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/vars.cmake")

resolve_env_or_var(QT_ROOT_DIR "" QT_INSTALL_DIR)
set(CMAKE_PREFIX_PATH "${QT_INSTALL_DIR};${CMAKE_PREFIX_PATH}")

project(
    ${PROJECT_TITLE}
    VERSION ${PROJECT_VERSION}
    LANGUAGES CXX
)

# Set default install prefix to local install directory if not specified
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(
        CMAKE_INSTALL_PREFIX
        "${CMAKE_CURRENT_SOURCE_DIR}/install"
        CACHE PATH "Default install directory" FORCE
    )
endif ()

find_package(
    Qt6 REQUIRED
    COMPONENTS Core
               Gui
               Quick
               Qml
               QuickControls2
               Concurrent
)

find_library(
    RESVG_LIB resvg
    PATHS ${RESVG_LIB_PATH}
    NO_DEFAULT_PATH REQUIRED
)

qt_standard_project_setup(REQUIRES 6.8)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/env.cmake")

# Debug output for QML files
message(STATUS "QML files found:")
foreach (qml_file ${SOURCES_QML})
    message(STATUS "  ${qml_file}")
endforeach ()

qt_add_executable(${PROJECT_NAME} ${SOURCES_CPP} ${SOURCES_HPP})

qt_add_qml_module(
    ${PROJECT_NAME_QML}
    URI "qml"
    QML_FILES ${SOURCES_QML}
    RESOURCE_PREFIX "/qt/qml"
    OUTPUT_DIRECTORY "qml"
)

target_include_directories(
    ${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src ${RESVG_ROOT_PATH}/crates/c-api
)

target_link_libraries(
    ${PROJECT_NAME}
    PUBLIC ${PROJECT_NAME_QML}
           Qt6::Core
           Qt6::Gui
           Qt6::Quick
           Qt6::Qml
           Qt6::QuickControls2
           Qt6::Concurrent
           ${RESVG_LIB}
)

install(
    TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

qt_generate_deploy_qml_app_script(
    TARGET ${PROJECT_NAME}
    OUTPUT_SCRIPT deploy_script
    MACOS_BUNDLE_POST_BUILD
    NO_UNSUPPORTED_PLATFORM_ERROR
    DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
    NO_TRANSLATIONS
)

install(SCRIPT ${deploy_script})

if (WIN32)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/windows.cmake")
elseif (APPLE)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/macos.cmake")
elseif (UNIX)
    target_compile_options(${PROJECT_NAME} PUBLIC -Wall -Werror -Wpedantic)
    # include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/linux.cmake")
else ()
    message(FATAL_ERROR "Unknown platform")
endif ()
