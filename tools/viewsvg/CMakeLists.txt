cmake_minimum_required(VERSION 3.22)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/vars.cmake")

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

qt_add_executable(${PROJECT_NAME} ${SOURCES_CPP} ${SOURCES_HPP})

qt_add_qml_module(
    ${PROJECT_NAME_QML}
    URI "qml"
    # VERSION 1.0
    QML_FILES ${SOURCES_QML}
    RESOURCE_PREFIX "/qt/qml" OUTPUT_DIRECTORY "qml"
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
endif ()
