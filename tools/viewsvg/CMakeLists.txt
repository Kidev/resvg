cmake_minimum_required(VERSION 3.22)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/functions.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/vars.cmake")

# IMPORTANT: Handle custom Qt path before finding packages
if(DEFINED QT_ROOT AND NOT "${QT_ROOT}" STREQUAL "")
    set(CMAKE_PREFIX_PATH "${QT_ROOT};${CMAKE_PREFIX_PATH}")
    message(STATUS "Using custom Qt path: ${QT_ROOT}")
elseif(DEFINED ENV{QT_ROOT} AND NOT "$ENV{QT_ROOT}" STREQUAL "")
    set(CMAKE_PREFIX_PATH "$ENV{QT_ROOT};${CMAKE_PREFIX_PATH}")
    message(STATUS "Using custom Qt path from environment: $ENV{QT_ROOT}")
endif()

project(
    ${PROJECT_TITLE}
    VERSION ${PROJECT_VERSION}
    LANGUAGES CXX
)

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

if (WIN32)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/windows.cmake")
elseif (APPLE)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/macos.cmake")
elseif (UNIX)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/linux.cmake")
else ()
    message(FATAL_ERROR "Unknown platform")
endif ()
