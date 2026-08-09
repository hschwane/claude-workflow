cmake_minimum_required(VERSION 3.20)
project(fixture VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_compile_options(-Wall -Wextra -Wpedantic -Werror)

add_library(fixture_core src/add.cpp)
target_include_directories(fixture_core PUBLIC src)

enable_testing()
add_subdirectory(tests)
