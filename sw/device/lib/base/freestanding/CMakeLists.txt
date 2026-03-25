add_library(freestanding INTERFACE)
add_library(opentitan::freestanding ALIAS libbase)

target_include_directories(freestanding INTERFACE ${CMAKE_CURRENT_LIST_DIR})
