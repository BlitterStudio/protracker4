# libpt4 - CMake build (MSVC, clang, gcc). Self-contained: no files from outside this directory.
#   cmake -S . -B build && cmake --build build
#   add_subdirectory(third_party/libpt4) -> target pt4 (static library, include dir exported)
cmake_minimum_required(VERSION 3.10)
project(libpt4 C)

set(PT4_SOURCES
    src/load.c
    src/replay.c
    src/voice.c
    src/api.c
    src/tables.c
    src/float.c
)

add_library(pt4 STATIC ${PT4_SOURCES})
target_include_directories(pt4 PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
set_target_properties(pt4 PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED ON C_EXTENSIONS OFF)
if(MSVC)
    target_compile_options(pt4 PRIVATE /W4)
else()
    target_compile_options(pt4 PRIVATE -Wall -Wextra -Wpedantic)
endif()

set(PT4_TOP OFF)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(PT4_TOP ON)
endif()
option(PT4_BUILD_TOOLS "build pt4play and the tests" ${PT4_TOP})
if(PT4_BUILD_TOOLS)
    add_executable(pt4play cli/pt4play.c)
    target_link_libraries(pt4play PRIVATE pt4)
    add_executable(pt4test test/pt4test.c)
    target_link_libraries(pt4test PRIVATE pt4)
    add_executable(pt4sum test/pt4sum.c)
    target_link_libraries(pt4sum PRIVATE pt4)
    if(MSVC)
        target_compile_definitions(pt4play PRIVATE _CRT_SECURE_NO_WARNINGS)
        target_compile_definitions(pt4test PRIVATE _CRT_SECURE_NO_WARNINGS)
        target_compile_definitions(pt4sum PRIVATE _CRT_SECURE_NO_WARNINGS)
    endif()
    enable_testing()
    add_test(NAME pt4test COMMAND pt4test ${CMAKE_CURRENT_SOURCE_DIR}/testdata)
endif()
