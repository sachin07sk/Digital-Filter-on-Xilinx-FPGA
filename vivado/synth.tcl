# ============================================
# Vivado Synthesis Script
# Run from Vivado Tcl Console:
#   source synth.tcl
# Or from command line:
#   vivado -mode batch -source synth.tcl
# Author: Saravana Kumar T J A
# ============================================

# ── Project settings ──────────────────────
set project_name "fir_filter"
set project_dir  "C:/VLSI_Projects/digital_filter/vivado/project"
set part_number  "xc7a35tcpg236-1"

# ── Create project ────────────────────────
create_project $project_name $project_dir \
    -part $part_number -force

# ── Add RTL sources ───────────────────────
add_files -norecurse {
    C:/VLSI_Projects/digital_filter/rtl/coefficient_rom.v
    C:/VLSI_Projects/digital_filter/rtl/fir_filter.v
    C:/VLSI_Projects/digital_filter/rtl/fir_top.v
}

# ── Set top module ────────────────────────
set_property top fir_top [current_fileset]

# ── Add constraints ───────────────────────
add_files -fileset constrs_1 -norecurse \
    C:/VLSI_Projects/digital_filter/vivado/constraints.xdc

# ── Run synthesis ─────────────────────────
puts "Starting synthesis..."
synth_design -top fir_top -part $part_number

# ── Run implementation ────────────────────
puts "Starting implementation..."
opt_design
place_design
route_design

# ── Generate reports ──────────────────────
report_timing_summary -file \
    C:/VLSI_Projects/digital_filter/vivado/timing_report.txt
report_utilization -file \
    C:/VLSI_Projects/digital_filter/vivado/utilization_report.txt
report_power -file \
    C:/VLSI_Projects/digital_filter/vivado/power_report.txt

# ── Generate bitstream ────────────────────
puts "Generating bitstream..."
write_bitstream -force \
    C:/VLSI_Projects/digital_filter/vivado/fir_filter.bit

puts "=========================================="
puts " Synthesis and Implementation COMPLETE"
puts " Check timing_report.txt for WNS"
puts " Check utilization_report.txt for LUT/FF"
puts "=========================================="
