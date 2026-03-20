cmake_minimum_required(VERSION 3.25)
project(example_cpp NONE)

if(DONT_COMPILE)
    return()
endif()

enable_language(ASM C CXX)
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/../../sdk/" sdk)

add_executable(${PROJECT_NAME} 
    ./main.cpp
    ./MyClass.cpp
)
link_application(${PROJECT_NAME})

