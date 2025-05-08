cmake_minimum_required(VERSION 3.22)

project(
    ViewSVG
    VERSION 1.0.0
    LANGUAGES CXX
)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-DVERSION_TAG="${VERSION_TAG}")

find_package(
    Qt6 REQUIRED
    COMPONENTS Core
               Gui
               Quick
               Qml
               QuickControls2
               Concurrent
)
qt_standard_project_setup(REQUIRES 6.8)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(RESVG_LIB_PATH "${CMAKE_SOURCE_DIR}/../../target/debug")
else ()
    set(RESVG_LIB_PATH "${CMAKE_SOURCE_DIR}/../../target/release")
endif ()

file(GLOB_RECURSE SOURCES_CPP src/*.cpp)
file(GLOB_RECURSE SOURCES_HPP src/*.hpp)

qt_add_executable(${PROJECT_NAME} ${SOURCES_CPP} ${SOURCES_HPP})
add_subdirectory(qml)

target_include_directories(
    ${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src ${CMAKE_SOURCE_DIR}/../../crates/c-api
)

if (WIN32)
    set(RESVG_LIB "${RESVG_LIB_PATH}/resvg.lib")
    target_compile_options(${PROJECT_NAME} PUBLIC /W4 /WX)
elseif (APPLE)
    if (EXISTS "${RESVG_LIB_PATH}/libresvg.a")
        set(RESVG_LIB "${RESVG_LIB_PATH}/libresvg.a")
    else ()
        set(RESVG_LIB "${RESVG_LIB_PATH}/libresvg.dylib")
    endif ()
    target_compile_options(${PROJECT_NAME} PUBLIC -Wall -Werror -Wpedantic)
else ()
    if (EXISTS "${RESVG_LIB_PATH}/libresvg.a")
        set(RESVG_LIB "${RESVG_LIB_PATH}/libresvg.a")
    else ()
        set(RESVG_LIB "${RESVG_LIB_PATH}/libresvg.so")
    endif ()
    target_compile_options(${PROJECT_NAME} PUBLIC -Wall -Werror -Wpedantic)
endif ()

# Link libraries
target_link_libraries(
    ${PROJECT_NAME}
    PRIVATE Qt6::Core
            Qt6::Gui
            Qt6::Quick
            Qt6::Qml
            Qt6::QuickControls2
            Qt6::Concurrent
            ${RESVG_LIB}
)

# Installation
include(GNUInstallDirs)

install(
    TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_generate_deploy_qml_app_script(
    TARGET ${PROJECT_NAME}
    OUTPUT_SCRIPT deploy_script
    MACOS_BUNDLE_POST_BUILD NO_UNSUPPORTED_PLATFORM_ERROR
    DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
)
install(SCRIPT ${deploy_script})
