# This script forces the processing order regardless of FuseSoC's internal logic
set target_file "constraints.xdc"
set file_obj [get_files -all -filter "NAME =~ *$target_file"]

if { $file_obj != "" } {
    set_property PROCESSING_ORDER LATE $file_obj
    puts "SUCCESS: Set PROCESSING_ORDER to LATE for $target_file"
} else {
    puts "ERROR: Could not find $target_file to set LATE property"
}