include_guard(GLOBAL)

function(get_source_dirs dirs search_dir)
    file(GLOB_RECURSE cmakelists ${search_dir}/*CMakeLists.txt)
    unset(result)

    foreach(cmakelist ${cmakelists})
        cmake_path(GET cmakelist PARENT_PATH source_dir)
        list(APPEND result ${source_dir})
    endforeach()
    set(${dirs} ${result} PARENT_SCOPE)
endfunction()


