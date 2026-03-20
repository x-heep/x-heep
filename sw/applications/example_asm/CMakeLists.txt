cmake_minimum_required(VERSION 3.25)
project(example_asm NONE)

if(DONT_COMPILE)
    return()
endif()

enable_language(ASM C)
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/../../sdk/" sdk)

add_executable(${PROJECT_NAME} 
    ./add.s
    ./multiply.S
    ./main.c
)
link_application(${PROJECT_NAME})
