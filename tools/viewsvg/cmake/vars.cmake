set(PROJECT_TITLE "viewsvg")

if (DEFINED VERSION_TAG AND NOT "${VERSION_TAG}" STREQUAL "")
    set(PROJECT_VERSION "${VERSION_TAG}" )
elseif (DEFINED ENV{VERSION_TAG} AND NOT "$ENV{VERSION_TAG}" STREQUAL "")
    set(PROJECT_VERSION "$ENV{VERSION_TAG}")
else ()
    set(PROJECT_VERSION "0.0.0")
endif ()

set(PROJECT_NAME_QML ${PROJECT_TITLE}_qml)

file(GLOB_RECURSE SOURCES_CPP src/*.cpp)
file(GLOB_RECURSE SOURCES_HPP src/*.hpp)

# First look for QML files in a qml directory, then in the root
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/qml")
    file(
        GLOB_RECURSE SOURCES_QML
        RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
        qml/*.qml
    )
else()
    file(
        GLOB_RECURSE SOURCES_QML
        RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
        *.qml
    )
endif()

# If no QML files found in subdirectory, check root
if(NOT SOURCES_QML)
    file(
        GLOB_RECURSE SOURCES_QML
        RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
        *.qml
    )
endif()

# Debug output
message(STATUS "SOURCES_QML: ${SOURCES_QML}")

set(RESVG_ROOT_PATH "${CMAKE_SOURCE_DIR}/../..")
set(RESVG_LIB_PATH "${RESVG_ROOT_PATH}/target/release")

add_definitions(-DVERSION_TAG="${PROJECT_VERSION}")

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
