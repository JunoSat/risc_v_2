# ==============================================================================
# build.tcl
# Vivado Automation Script for RISC-V Processor Deployment
# Target: Nexys A7-100T (xc7a100tcsg324-1)
# ==============================================================================

set project_name "riscv_fpga"
set target_part "xc7a100tcsg324-1"

# Create a fresh pristine Vivado project
create_project -force $project_name ./$project_name -part $target_part

# Add all Verilog RTL files from the current directory
add_files [glob *.v]
add_files [glob *.vh]

# Add constraints file
add_files constraint.xdc

# Add hex memory initialization files (if required dynamically)
add_files imem.hex
add_files dmem.hex

# Define the top-level module correctly
set_property top top_fpga [current_fileset]
update_compile_order -fileset sources_1

# Run Synthesis
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Run Implementation
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# Generate Bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Print final confirmation
puts "\n============================================="
puts "Build Complete!"
puts "Bitstream generated at: ./$project_name/$project_name.runs/impl_1/top_fpga.bit"
puts "=============================================\n"
