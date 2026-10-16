# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

if {[llength $argv] != 3} {
  puts stderr "usage: tclsh gen_postsyn_cells.tcl <tech> <netlist.v> <out.v>"
  exit 2
}
lassign $argv tech netlist_file out_file
set here [file dirname [info script]]
source [file join $here .. .. asic tech $tech.tcl]

proc die {msg} { puts stderr "\[gen_postsyn_cells] ERROR: $msg"; exit 1 }
proc note {msg} { puts "\[gen_postsyn_cells] $msg" }

proc read_file {f} {
  set fh [open $f r]
  set t [read $fh]
  close $fh
  return $t
}

# ---------------------------------------------------------------------------
# Liberty parser: group = {type args attrs children}, attrs a dict.
# ---------------------------------------------------------------------------

proc lib_unquote {s} {
  if {[string index $s 0] eq "\"" && [string index $s end] eq "\""} {
    return [string range $s 1 end-1]
  }
  return $s
}

proc lib_body {} {
  set attrs [dict create]
  set children {}
  while {$::LI < $::LN} {
    set t [lindex $::LT $::LI]
    incr ::LI
    if {$t eq "\}"} { break }
    if {$t eq ";" || $t eq ","} { continue }
    set nx [lindex $::LT $::LI]
    if {$nx eq ":"} {
      incr ::LI
      dict set attrs $t [lib_unquote [lindex $::LT $::LI]]
      incr ::LI
      if {[lindex $::LT $::LI] eq ";"} { incr ::LI }
    } elseif {$nx eq "("} {
      incr ::LI
      set args {}
      while {$::LI < $::LN && [set a [lindex $::LT $::LI]] ne ")"} {
        if {$a ne ","} { lappend args [lib_unquote $a] }
        incr ::LI
      }
      incr ::LI
      if {[lindex $::LT $::LI] eq "\{"} {
        incr ::LI
        lassign [lib_body] ga gc
        lappend children [list $t $args $ga $gc]
      } else {
        if {[lindex $::LT $::LI] eq ";"} { incr ::LI }
        dict set attrs $t $args
      }
    }
  }
  return [list $attrs $children]
}

# Returns the `cell` groups of a Liberty file.
proc lib_cells {file} {
  set text [read_file $file]
  regsub -all {/\*.*?\*/} $text " " text
  regsub -all {\\\r?\n} $text " " text
  set ::LT [regexp -all -inline {"(?:[^"\\]|\\.)*"|[(){}:;,]|[^\s(){}:;,"]+} $text]
  set ::LN [llength $::LT]
  set ::LI 0
  set cells {}
  foreach top [lindex [lib_body] 1] {
    if {[lindex $top 0] ne "library"} { continue }
    foreach g [lindex $top 3] {
      if {[lindex $g 0] eq "cell"} { lappend cells $g }
    }
  }
  return $cells
}

proc g_attr {g name {default ""}} {
  set a [lindex $g 2]
  if {[dict exists $a $name]} { return [dict get $a $name] }
  return $default
}

proc g_children {g type} {
  set res {}
  foreach c [lindex $g 3] {
    if {[lindex $c 0] eq $type} { lappend res $c }
  }
  return $res
}

# ---------------------------------------------------------------------------
# Liberty boolean expressions -> Verilog. Precedence (Liberty reference):
# inversion (! prefix, ' postfix) first, then ^, then AND (* & or blank),
# then OR (+ |). The result is fully parenthesized.
# ---------------------------------------------------------------------------

proc fx_is_operand_start {t} {
  return [expr {$t eq "!" || $t eq "(" || [regexp {^[A-Za-z_0-9]} $t]}]
}

proc fx_primary {} {
  set t [lindex $::FT $::FI]
  incr ::FI
  if {$t eq "("} {
    set e [fx_or]
    if {[lindex $::FT $::FI] ne ")"} { error "missing ) in '$::FX'" }
    incr ::FI
  } elseif {$t eq "0"} {
    set e "1'b0"
  } elseif {$t eq "1"} {
    set e "1'b1"
  } elseif {[regexp {^[A-Za-z_]} $t]} {
    set e $t
  } else {
    error "unexpected '$t' in '$::FX'"
  }
  while {[lindex $::FT $::FI] eq "'"} {
    incr ::FI
    set e "(~$e)"
  }
  return $e
}

proc fx_unary {} {
  if {[lindex $::FT $::FI] eq "!"} {
    incr ::FI
    return "(~[fx_unary])"
  }
  return [fx_primary]
}

proc fx_xor {} {
  set e [fx_unary]
  while {[lindex $::FT $::FI] eq "^"} {
    incr ::FI
    set e "($e ^ [fx_unary])"
  }
  return $e
}

proc fx_and {} {
  set e [fx_xor]
  while {1} {
    set t [lindex $::FT $::FI]
    if {$t eq "*" || $t eq "&"} {
      incr ::FI
    } elseif {$::FI >= [llength $::FT] || ![fx_is_operand_start $t]} {
      break
    }
    set e "($e & [fx_xor])"
  }
  return $e
}

proc fx_or {} {
  set e [fx_and]
  while {[lindex $::FT $::FI] in {+ |}} {
    incr ::FI
    set e "($e | [fx_and])"
  }
  return $e
}

proc lib_expr {expr} {
  set ::FX $expr
  set ::FT [regexp -all -inline {[A-Za-z_][A-Za-z0-9_]*|[01]|[!'*&+|^()]} $expr]
  set ::FI 0
  if {[llength $::FT] == 0} { error "empty expression" }
  set e [fx_or]
  if {$::FI != [llength $::FT]} { error "trailing tokens in '$expr'" }
  return $e
}

# ---------------------------------------------------------------------------
# Liberty cell -> Verilog module
# ---------------------------------------------------------------------------

# Value of a clear_preset_var when clear and preset are both active.
proc cpv_value {v var} {
  switch -- $v {
    L { return "1'b0" }
    H { return "1'b1" }
    N { return $var }
    T { return "~$var" }
    X { return "1'bx" }
    default { return "1'bx" }
  }
}

# Sequential element (ff or latch group) -> Verilog lines.
proc seq_model {cell g kind idx} {
  lassign [lindex $g 1] q qn
  set p "${kind}${idx}"
  set clr [g_attr $g clear]
  set pre [g_attr $g preset]
  set lines {}
  lappend lines "  reg $q;"
  if {$qn ne ""} { lappend lines "  reg $qn;" }
  if {$kind eq "ff"} {
    set clk [g_attr $g clocked_on]
    set nxt [g_attr $g next_state]
    if {$clk eq "" || $nxt eq ""} { error "$cell: ff without clocked_on/next_state" }
    lappend lines "  wire ${p}_clk = [lib_expr $clk];"
    lappend lines "  wire ${p}_d = [lib_expr $nxt];"
  } else {
    set en [g_attr $g enable]
    set din [g_attr $g data_in]
    if {$en eq "" || $din eq ""} { error "$cell: latch without enable/data_in" }
    lappend lines "  wire ${p}_en = [lib_expr $en];"
    lappend lines "  wire ${p}_d = [lib_expr $din];"
  }
  set ev {}
  if {$clr ne ""} { lappend lines "  wire ${p}_clr = [lib_expr $clr];" }
  if {$pre ne ""} { lappend lines "  wire ${p}_pre = [lib_expr $pre];" }

  # Branches, highest priority first: {condition q-value qn-value}
  set br {}
  if {$clr ne "" && $pre ne ""} {
    lappend br [list "${p}_clr && ${p}_pre" \
      [cpv_value [g_attr $g clear_preset_var1 X] $q] \
      [cpv_value [g_attr $g clear_preset_var2 X] [expr {$qn ne "" ? $qn : "1'bx"}]]]
  }
  if {$clr ne ""} { lappend br [list "${p}_clr" "1'b0" "1'b1"] }
  if {$pre ne ""} { lappend br [list "${p}_pre" "1'b1" "1'b0"] }

  if {$kind eq "ff"} {
    set sens "posedge ${p}_clk"
    if {$clr ne ""} { append sens " or posedge ${p}_clr" }
    if {$pre ne ""} { append sens " or posedge ${p}_pre" }
    lappend lines "  always @($sens) begin"
    set asg "<="
    lappend br [list "" "${p}_d" "~${p}_d"]
  } else {
    lappend lines "  always_latch begin"
    set asg "="
    lappend br [list "${p}_en" "${p}_d" "~${p}_d"]
  }
  set first 1
  foreach b $br {
    lassign $b cond qv qnv
    if {$cond eq ""} {
      set head [expr {$first ? "    begin" : "    else begin"}]
    } else {
      set head [expr {$first ? "    if ($cond) begin" : "    else if ($cond) begin"}]
    }
    lappend lines $head
    lappend lines "      $q $asg $qv;"
    if {$qn ne ""} { lappend lines "      $qn $asg $qnv;" }
    lappend lines "    end"
    set first 0
  }
  lappend lines "  end"
  return $lines
}

# Integrated clock-gating cell (its statetable is described by attributes).
proc icg_model {cell kind pins} {
  set clk ""; set en ""; set te ""; set gclk ""
  foreach p $pins {
    set n [lindex $p 1 0]
    if {[g_attr $p clock_gate_clock_pin] eq "true"} { set clk $n }
    if {[g_attr $p clock_gate_enable_pin] eq "true"} { set en $n }
    if {[g_attr $p clock_gate_test_pin] eq "true"} { set te $n }
    if {[g_attr $p clock_gate_out_pin] eq "true"} { set gclk $n }
  }
  if {$clk eq "" || $en eq "" || $gclk eq ""} { error "$cell: incomplete clock-gating pin attributes" }
  set lines [list "  reg en_q;"]
  switch -- $kind {
    latch_posedge_precontrol {
      if {$te eq ""} { error "$cell: precontrol without test pin" }
      lappend lines "  always_latch if (!$clk) en_q = $en | $te;" "  assign $gclk = $clk & en_q;"
    }
    latch_posedge_postcontrol {
      if {$te eq ""} { error "$cell: postcontrol without test pin" }
      lappend lines "  always_latch if (!$clk) en_q = $en;" "  assign $gclk = $clk & (en_q | $te);"
    }
    latch_posedge {
      lappend lines "  always_latch if (!$clk) en_q = $en;" "  assign $gclk = $clk & en_q;"
    }
    latch_negedge_precontrol {
      if {$te eq ""} { error "$cell: precontrol without test pin" }
      lappend lines "  always_latch if ($clk) en_q = $en | $te;" "  assign $gclk = $clk | ~en_q;"
    }
    latch_negedge {
      lappend lines "  always_latch if ($clk) en_q = $en;" "  assign $gclk = $clk | ~en_q;"
    }
    default { error "$cell: unsupported clock_gating_integrated_cell '$kind'" }
  }
  return $lines
}

proc cell_model {cell g} {
  set pins {}
  foreach p [g_children $g pin] {
    if {[g_attr $p direction] eq "internal"} { continue }
    lappend pins $p
  }
  if {[llength [g_children $g bus]] > 0 || [llength [g_children $g bundle]] > 0} {
    error "$cell: bus/bundle pins not supported"
  }
  set names {}
  set decls {}
  foreach p $pins {
    foreach n [lindex $p 1] {
      lappend names $n
      set dir [g_attr $p direction input]
      if {$dir ni {input output inout}} { error "$cell: pin $n has direction '$dir'" }
      lappend decls "  $dir $n;"
    }
  }
  set body {}
  set icg [g_attr $g clock_gating_integrated_cell]
  if {$icg ne ""} {
    set body [icg_model $cell $icg $pins]
  } else {
    if {[llength [g_children $g statetable]] > 0} { error "$cell: statetable not supported" }
    set i 0
    foreach s [g_children $g ff] { set body [concat $body [seq_model $cell $s ff $i]]; incr i }
    set i 0
    foreach s [g_children $g latch] { set body [concat $body [seq_model $cell $s latch $i]]; incr i }
    foreach p $pins {
      set f [g_attr $p function]
      if {$f eq ""} { continue }
      set n [lindex $p 1 0]
      set v [lib_expr $f]
      set ts [g_attr $p three_state]
      if {$ts ne ""} { set v "([lib_expr $ts]) ? 1'bz : $v" }
      lappend body "  assign $n = $v;"
    }
  }
  return [join [concat [list "module $cell ([join $names {, }]);"] $decls $body [list "endmodule"]] "\n"]
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if {[catch {
  # Cell types the netlist instantiates (instances of modules it does not define).
  set defined [dict create]
  set used [dict create]
  set kw {module endmodule input output inout wire reg assign always initial begin end if else
          supply0 supply1 tri wand wor parameter localparam genvar integer logic generate endgenerate}
  foreach line [split [read_file $netlist_file] "\n"] {
    # (DC may indent a module header)
    if {[regexp {^\s*module\s+(\\\S+|[A-Za-z_][\w$]*)} $line -> m]} {
      dict set defined $m 1
    } elseif {[regexp {^\s+(\\\S+|[A-Za-z_][\w$]*)\s+(\\\S+|[A-Za-z_][\w$]*)\s*\(} $line -> t]} {
      if {$t ni $kw} { dict set used $t 1 }
    }
  }
  set used_cells {}
  foreach t [dict keys $used] {
    if {![dict exists $defined $t]} { lappend used_cells $t }
  }
  note "netlist: [dict size $defined] modules, [llength $used_cells] library cell types"

  # Std cells from the Liberty.
  set models {}
  set modeled [dict create]
  foreach lib [tech_stdcell_libs] {
    note "std cells from $lib"
    foreach g [lib_cells $lib] {
      set cell [lindex $g 1 0]
      if {[dict exists $modeled $cell]} { continue }
      if {[catch {cell_model $cell $g} m]} {
        # Only fatal if the netlist uses it.
        if {$cell in $used_cells} { error $m }
        note "skipped (unused, $m)"
        continue
      }
      lappend models "// Generated from Liberty cell $cell\n$m"
      dict set modeled $cell 1
    }
  }
  note "[dict size $modeled] std-cell models generated"

  # Other cells (SRAM macros, IO pads): the technology's models, with the
  # files they depend on.
  set mod_file [dict create]
  set file_text [dict create]
  foreach f [tech_sim_macro_models] {
    set t [read_file $f]
    dict set file_text $f $t
    foreach {-> m} [regexp -all -inline -line {^\s*(?:module|primitive)\s+([A-Za-z_]\w*)} $t] {
      if {![dict exists $mod_file $m]} { dict set mod_file $m $f }
    }
  }
  set need {}
  foreach c $used_cells {
    if {[dict exists $modeled $c]} { continue }
    if {![dict exists $mod_file $c]} { error "no model for library cell '$c' (not in the Liberty nor in [tech_sim_macro_models])" }
    set f [dict get $mod_file $c]
    if {$f ni $need} { lappend need $f }
  }
  for {set i 0} {$i < [llength $need]} {incr i} {
    set t [dict get $file_text [lindex $need $i]]
    dict for {m f} $mod_file {
      if {$f ni $need && [regexp "\\m$m\\M" $t]} { lappend need $f }
    }
  }

  set defines {}
  foreach flag $TECH_SIM_VLOG_FLAGS {
    if {[regexp {^\+define\+([A-Za-z_]\w*)(?:=(.*))?$} $flag -> name val]} {
      lappend defines "`define $name $val"
    }
  }

  set fh [open $out_file w]
  puts $fh "// Auto-generated by scripts/sim/verilator/gen_postsyn_cells.tcl ($tech) - do not edit."
  puts $fh "// Cell models for the Verilator post-synthesis simulation of [file tail $netlist_file]."
  puts $fh "// PDK-derived: keep private.\n"
  foreach d $defines { puts $fh $d }
  puts $fh ""
  puts $fh [join $models "\n\n"]
  foreach f $need {
    note "models from $f"
    set t [dict get $file_text $f]
    regsub -all -line {^\s*`timescale.*$} $t "" t
    regsub -all {`ifndef\s+SYNTHESIS\M} $t "`ifndef VERILATOR // was: SYNTHESIS" t
    puts $fh "\n// ---- from $f ----"
    puts $fh $t
  }
  close $fh
  note "wrote $out_file"
} err]} {
  die $err
}
