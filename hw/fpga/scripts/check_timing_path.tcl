# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

proc require_env {name} {
  if {![info exists ::env($name)] || $::env($name) eq ""} {
    error "Environment variable $name is required."
  }
  return $::env($name)
}

proc optional_env {name default_value} {
  if {[info exists ::env($name)] && $::env($name) ne ""} {
    return $::env($name)
  }
  return $default_value
}

proc resolve_single_pin {label spec} {
  set pins [get_pins -quiet $spec]
  if {[llength $pins] == 0} {
    set pins [get_pins -quiet -hier -filter [format {NAME =~ "%s"} $spec]]
  }

  if {[llength $pins] == 0} {
    error "No pins matched $label specification: $spec"
  }

  if {[llength $pins] > 1} {
    puts "Matched multiple pins for $label specification: $spec"
    foreach pin $pins {
      puts "  $pin"
    }
    error "Expected a single pin for $label."
  }

  return [lindex $pins 0]
}

set dcp_path [require_env XHEEP_TIMING_DCP]
set from_spec [require_env XHEEP_TIMING_FROM]
set to_spec [require_env XHEEP_TIMING_TO]
set xdc_list [optional_env XHEEP_TIMING_XDCS ""]
set max_paths [optional_env XHEEP_TIMING_MAX_PATHS 1]
set report_exceptions_enable [optional_env XHEEP_TIMING_REPORT_EXCEPTIONS 1]

puts "Opening checkpoint: $dcp_path"
open_checkpoint $dcp_path

if {$xdc_list ne ""} {
  foreach xdc_path [split $xdc_list ";"] {
    if {$xdc_path eq ""} {
      continue
    }
    puts "Reading XDC: $xdc_path"
    read_xdc $xdc_path
  }
}

set src_pin [resolve_single_pin "from" $from_spec]
set dst_pin [resolve_single_pin "to" $to_spec]

puts "Resolved source pin: $src_pin"
puts "Resolved destination pin: $dst_pin"

if {$report_exceptions_enable} {
  puts "\n=== report_exceptions ==="
  report_exceptions -from $src_pin -to $dst_pin
}

puts "\n=== report_timing ==="
report_timing -from $src_pin -to $dst_pin -max_paths $max_paths -input_pins -routable_nets

close_design
