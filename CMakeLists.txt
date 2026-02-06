cmake_minimum_required(VERSION 3.15)
project(fero VERSION 0.1.0 LANGUAGES CXX)

option(BUILD_EXAMPLES "Build example binaries" ON)
## Require C++17 for the project so std::optional and other features are available
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_subdirectory(core)

add_subdirectory(tests)

enable_testing()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
