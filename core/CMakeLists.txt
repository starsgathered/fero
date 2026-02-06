cmake_minimum_required(VERSION 3.15)
project(fero_core LANGUAGES CXX)

add_library(fero STATIC
  src/fero.cpp
  src/initial_sync_manager.cpp
)

target_include_directories(fero PUBLIC
  $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include>
)

if(BUILD_EXAMPLES)
  add_executable(fero_example examples/example.cpp)
  target_link_libraries(fero_example PRIVATE fero)
endif()