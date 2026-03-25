cmake_minimum_required(VERSION 3.25)
project(hello_world 
    LANGUAGES NONE
    DESCRIPTION "Simple hello world program")

if(DONT_COMPILE)
    return()
endif()

enable_language(ASM C)
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/../../sdk/" sdk)

add_executable(${PROJECT_NAME} ./main.c)
link_application(${PROJECT_NAME})
