set(FETCHCONTENT_UPDATES_DISCONNECTED ON)
set(FETCHCONTENT_QUIET OFF)

include(FetchContent)
FetchContent_Declare(SoCMake
    GIT_REPOSITORY "https://github.com/HEP-SoC/SoCMake.git"
    GIT_TAG develop)

FetchContent_MakeAvailable(SoCMake)

#include("${CMAKE_CURRENT_LIST_DIR}/python_deps.cmake")