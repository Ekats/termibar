cmake_minimum_required(VERSION 3.16)
project(termibarplugin)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)

set(QT_MAJOR_VERSION 6)
set(QT_DEFAULT_MAJOR_VERSION 6)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Widgets)
find_package(KF6 REQUIRED COMPONENTS Parts)

qt_policy(SET QTP0001 NEW)

qt_add_qml_module(termibarplugin
    URI org.termibar
    VERSION 1.0
    PLUGIN_TARGET termibarplugin
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/org/termibar
    SOURCES
        konsoleitem.h
        konsoleitem.cpp
)

target_link_libraries(termibarplugin PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Widgets
    KF6::Parts
)

# Standalone test harness
add_executable(termibar-test test_main.cpp)
target_compile_definitions(termibar-test PRIVATE
    SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(termibar-test PRIVATE
    Qt6::Quick
    Qt6::Widgets
)

install(TARGETS termibarplugin
    DESTINATION ${KDE_INSTALL_QMLDIR}/org/termibar)
