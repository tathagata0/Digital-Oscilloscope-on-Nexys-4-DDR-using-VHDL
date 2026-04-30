open_project C:/Users/Asus/.gemini/antigravity/scratch/nexys4_oscilloscope/nexys4_oscilloscope.xpr
add_files -fileset sim_1 -norecurse C:/Users/Asus/.gemini/antigravity/scratch/nexys4_oscilloscope/sim/tb_oscilloscope.vhd
set_property top tb_oscilloscope [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1
close_project
