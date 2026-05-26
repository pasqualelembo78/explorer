cmake_minimum_required(VERSION 3.5.2)

add_subdirectory("mstch")

project(myext)

# CMake < 3.18 non accetta STATIC senza sorgenti, usiamo INTERFACE
add_library(myext INTERFACE)

target_include_directories(myext INTERFACE
        "${CMAKE_CURRENT_SOURCE_DIR}"
)
