# create_nexys4_project.tcl
# Usage: vivado -mode batch -source scripts/create_nexys4_project.tcl -tclargs ./_vivado_nexys4

set out_dir [lindex $argv 0]
if { $out_dir eq "" } {
  set out_dir "./_vivado_nexys4"
}

set repo_root [file normalize [file dirname [info script]]/..]
set proj_name "nexys4_oscilloscope"
set proj_dir [file normalize "$out_dir/$proj_name"]

file mkdir $out_dir

# Create project for Nexys 4 DDR (Artix-7 XC7A100T-1CSG324)
create_project $proj_name $proj_dir -part xc7a100tcsg324-1 -force
set_property target_language VHDL [current_project]

# Add HDL sources
set src_dir [file normalize "$repo_root/src"]
set src_files [glob -nocomplain -directory $src_dir *.vhd]
add_files -fileset sources_1 $src_files

# Add constraints
set xdc_file [file normalize "$repo_root/constraints/nexys4_ddr.xdc"]
add_files -fileset constrs_1 $xdc_file

# Set top module
set_property top oscilloscope_top [current_fileset]
update_compile_order -fileset sources_1

puts "=========================================================="
puts "Project created at: $proj_dir"
puts "Next steps:"
puts "1. Open the project in Vivado GUI."
puts "2. Open IP Catalog and search for 'XADC Wizard'."
puts "3. Customize XADC Wizard with component name 'xadc_wiz_0'."
puts "4. In 'Basic' tab: Interface: DRP, Startup Channel: Single Channel."
puts "5. In 'ADC Setup' tab: Single Channel: VAUXP3 VAUXN3."
puts "6. In 'Alarms' tab: Uncheck all alarms."
puts "7. Generate the IP."
puts "8. Run Synthesis, Implementation, and Generate Bitstream."
puts "=========================================================="

close_project
exit
