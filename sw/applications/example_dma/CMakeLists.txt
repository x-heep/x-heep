cmake_minimum_required(VERSION 3.27)
project(example_dma NONE)

if(DONT_COMPILE)
    return()
endif()

enable_language(ASM C CXX)
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/../../sdk/" sdk)

add_executable(${PROJECT_NAME} ./main.c)

link_application(${PROJECT_NAME})
