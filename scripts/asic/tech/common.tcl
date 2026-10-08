# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Value of environment variable $name, or "" if unset.
proc asic_env {name} {
  if {[info exists ::env($name)]} { return [string trim $::env($name)] }
  return ""
}

# Design-kit root taken from environment variable $var; errors if unset.
proc asic_root {var what} {
  set root [asic_env $var]
  if {$root eq ""} {
    error "\[asic] \$$var is not set: export it as the $what root."
  }
  if {![file isdirectory $root]} {
    error "\[asic] \$$var=$root is not a directory."
  }
  return [file normalize $root]
}

# Resolves a list of files: the paths in environment variable $override
# (whitespace-separated) when set, otherwise the matches of the first glob
# pattern in $patterns that matches anything. Errors when nothing is found,
# unless $required is 0 (then returns {}).
proc asic_find {what override patterns {required 1}} {
  set ov [asic_env $override]
  if {$ov ne ""} {
    set files {}
    foreach f $ov {
      if {![file exists $f]} { error "\[asic] \$$override: $f does not exist." }
      lappend files [file normalize $f]
    }
    return $files
  }
  foreach p $patterns {
    set files [lsort [glob -nocomplain -- $p]]
    if {[llength $files] > 0} { return $files }
  }
  if {$required} {
    error "\[asic] no $what found. Tried:\n  [join $patterns "\n  "]\nSet \$$override to the file(s) explicitly."
  }
  return {}
}
