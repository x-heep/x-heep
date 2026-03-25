function(get_subdirs dirs search_dir)
    file(GLOB dir_list LIST_DIRECTORIES TRUE ${search_dir}/*)
    unset(result)

    foreach(dir ${dir_list})
        if(IS_DIRECTORY ${dir})
            list(APPEND result ${dir})
        endif()
    endforeach()
    set(${dirs} ${result} PARENT_SCOPE)
endfunction()


function(create_lib created_lib dir)
    cmake_path(GET dir FILENAME dirname)

    file(GLOB c_files ${dir}/*.c)
    file(GLOB h_files ${dir}/*.h)
    file(GLOB asm_files ${dir}/*.h)

    add_library(${dirname} INTERFACE
        )

    target_sources(${dirname} PUBLIC
        ${asm_files}
        ${c_files}
        ${h_files}
    )
    target_include_directories(${dirname} INTERFACE ${dir})

    set(${created_lib} ${dirname} PARENT_SCOPE)
endfunction()

get_subdirs(dir_list ${CMAKE_CURRENT_LIST_DIR})

unset(libs)
foreach(dir ${dir_list})
    create_lib(created_lib "${dir}")
    list(APPEND libs ${created_lib})
endforeach()

set(DRIVER_LIBS ${libs} PARENT_SCOPE)
