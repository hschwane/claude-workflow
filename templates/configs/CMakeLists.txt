cmake_minimum_required(VERSION 3.25)
project({{PROJECT_NAME}} VERSION 0.1.0 LANGUAGES CXX)

# C++23 standard
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Export compile commands for clangd/clang-tidy
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Strict warnings
add_compile_options(
  -Wall -Wextra -Wpedantic
  -Wno-unused-parameter
  -Wshadow
  -Wconversion
  -Wsign-conversion
  $<$<CONFIG:Debug>:-fsanitize=address,undefined>
  $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
)
add_link_options(
  $<$<CONFIG:Debug>:-fsanitize=address,undefined>
)

# Version header generation
configure_file(
  "${CMAKE_SOURCE_DIR}/src/version.h.in"
  "${CMAKE_BINARY_DIR}/generated/version.h"
)
include_directories("${CMAKE_BINARY_DIR}/generated")

# CMake presets (see CMakePresets.json)
include(CMakePackageConfigHelpers)

# Dependencies via FetchContent or vcpkg
# include(FetchContent)
# FetchContent_Declare(...)

# Source
add_subdirectory(src)

# Tests
enable_testing()
add_subdirectory(tests)
