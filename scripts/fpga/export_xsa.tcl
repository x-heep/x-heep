# 1. Open the Project
set project_file [glob -nocomplain *.xpr]
if {$project_file eq ""} { puts "ERROR: No .xpr file found"; exit 1 }
open_project $project_file

# 2. Update Compile Order to ensure the Wrapper is Top
update_compile_order -fileset sources_1

# 3. Open the Block Design to ensure it's loaded
#    (This is still good practice to ensure metadata is available)
set bd_files [get_files *.bd]
if {[llength $bd_files] > 0} {
    open_bd_design [lindex $bd_files 0]
}

# 4. Open the Implemented Design (the Wrapper)
#    This forces Vivado to use the full system context
open_run impl_1

# 5. Write the XSA from the IMPLEMENTED design context
#    This captures the full hierarchy including the wrapper and the BD
write_hw_platform -fixed -include_bit -force -file core_v_mini_mcu.xsa