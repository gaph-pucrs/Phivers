################################################################################
# Phivers PE - block level constraints
#
# PhiversPE is synthesised as a block, not as a chip: the memory, NoC and
# BrLite interfaces connect to neighbouring blocks on the same die, so the
# environment is modelled with a standard cell driver and a lumped output
# load instead of IO pads.
#
# $CLK_PERIOD, $CLK_NAME, ... come from scripts/setup.tcl.
################################################################################

set sdc_version 2.0
set_time_unit -nanoseconds
set_load_unit -picofarads

################################################################################
# Clock
################################################################################

create_clock -name $CLK_NAME -period $CLK_PERIOD [get_ports $CLK_PORT]

# Clock tree does not exist yet: model it so that synthesis is not optimistic.
set_clock_uncertainty -setup [expr {$CLK_PERIOD * 0.05}] [get_clocks $CLK_NAME]
set_clock_uncertainty -hold  0.05                        [get_clocks $CLK_NAME]
set_clock_transition         0.10                        [get_clocks $CLK_NAME]
set_clock_latency            0.30                        [get_clocks $CLK_NAME]
set_clock_latency -source    0.00                        [get_clocks $CLK_NAME]

################################################################################
# Reset
################################################################################

# rst_ni is an asynchronous active-low reset (always_ff @(posedge clk_i or
# negedge rst_ni)). Its release is synchronised at the system level, so the
# path is not timed here; recovery/removal is checked after CTS.
set_false_path -from [get_ports $RST_PORT]

################################################################################
# IO timing
################################################################################

set design_inputs  [remove_from_collection [all_inputs] [get_ports [list $CLK_PORT $RST_PORT]]]
set design_outputs [all_outputs]

# 40% of the period is budgeted outside the block on each side.
set_input_delay  -clock $CLK_NAME [expr {$CLK_PERIOD * 0.40}] $design_inputs
set_output_delay -clock $CLK_NAME [expr {$CLK_PERIOD * 0.40}] $design_outputs

set_driving_cell -lib_cell $DRIVING_CELL -pin $DRIVING_PIN $design_inputs
set_load 0.025 $design_outputs ;# 25 fF

################################################################################
# Design rules
################################################################################

set_max_fanout    20   [current_design]
set_max_transition 0.30 [current_design]
