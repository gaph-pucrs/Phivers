################################################################################
# Phivers - synthesis of a single PE (PhiversPE) with Cadence Genus
#
# Run it from synth/ with:  make synth
# or by hand:               cd work/<run> && genus -files ../../scripts/synth.tcl
################################################################################

source [file dirname [info script]]/setup.tcl
source $SCRIPTS_DIR/reports.tcl

file mkdir $REPORTS_DIR
file mkdir $OUTPUTS_DIR

banner "Phivers PE synthesis - $TOP_MODULE @ ${CLK_PERIOD}ns - run $RUN_NAME"
puts "  scripts : $SCRIPTS_DIR"
puts "  work    : $WORK_DIR"
puts "  reports : $REPORTS_DIR"
puts "  outputs : $OUTPUTS_DIR"

################################################################################
# Tool configuration
# https://support.cadence.com/apex/techpubDocViewerPage?xmlName=genus_user.xml&title=Genus%20User%20Guide%20--%20Retiming%20the%20Design%20-%20Retiming%20the%20Design&hash=&c_version=23.1&path=genus_user/genus_user23.1/Retiming_the_Design.html
################################################################################

banner "Tool configuration"

set_multi_cpu_usage -local_cpu $NUM_CPUS
set_db super_thread_debug_directory $WORK_DIR

set_db information_level        4
set_db detailed_sdc_messages    true

# Keep the RTL hierarchy:
set_db auto_ungroup             none

set_db syn_global_effort        $SYN_EFFORT
set_db design_power_effort      $POWER_EFFORT
set_db lp_insert_clock_gating   $CLOCK_GATING
set_db lp_default_probability   0.5

# Latches are not intended in this design: report them, and optionally abort.
set_db hdl_error_on_latch       $ERROR_ON_LATCH

set_db hdl_language             sv
set_db hdl_zero_replicate_is_null true

# Retiming (off by default - enable with: make synth RETIME=true)
set_db retime_async_reset       true
set_db retime_effort_level      high
set_db retime_reg_naming_suffix _retimed_reg
set_db retime_verification_flow $WRITE_LEC

################################################################################
# Libraries and physical data
################################################################################

banner "Reading MMMC setup"

read_mmmc $SCRIPTS_DIR/views.mmmc

if {$CLOCK_GATING} {
    # The TSMC libraries flag part of the integrated clock gating cells as
    # "avoid": make them usable or clock gating has nothing to map to.
    set cg_cells [get_db lib_cells -if {.clock_gating_integrated_cell != ""}]
    if {[llength $cg_cells] > 0} {
        set_db $cg_cells .avoid false
        puts "Clock gating: [llength $cg_cells] integrated cells made usable"
    }
}

# Wire load estimated from a virtual layout instead of a wire load model
banner "Reading physical data (LEF)"
read_physical -lefs "$TECH_LEF $STDCELL_LEF"
set_db interconnect_mode ple

################################################################################
# RTL
################################################################################

banner "Reading RTL"

read_hdl -define SYNTH -f $SCRIPTS_DIR/rtl.f

banner "Elaborating $TOP_MODULE"

if {[llength $DESIGN_PARAMS] > 0} {
    puts "Parameter overrides: $DESIGN_PARAMS"
    elaborate $TOP_MODULE -parameters $DESIGN_PARAMS

    # Genus mangles the design name when parameters are overridden
    # (PhiversPE_VEnable1_VLEN128). Put it back, so that the netlist, the SDC
    # and the Innovus hand-off all name the block PhiversPE whatever the
    # configuration is - the configuration is what the run directory is for.
    if {[get_db [current_design] .name] ne $TOP_MODULE} {
        if {[catch {rename_obj [current_design] $TOP_MODULE} msg]} {
            puts "WARNING: could not rename the top design back to $TOP_MODULE"
            puts "         $msg"
        }
    }
} else {
    elaborate $TOP_MODULE
}

puts "Top design: [get_db [current_design] .name]"

init_design

check_dft_rules

# The PE has no scan chains inserted at this level
set_db [current_design] .dft_dont_scan true

if {$RETIME} {
    set_db [current_design] .retime true
}


################################################################################
# Synthesis
################################################################################

banner "Synthesis - mapping and optimization"

syn_generic
syn_map
syn_opt

uniquify $TOP_MODULE

report_final


################################################################################
# Deliverables
################################################################################

banner "Writing deliverables"

# MMMC: the write commands need to be told which view to write for. The SDC
# and the SDF are emitted for the setup signoff corner.
set SIGNOFF_VIEW av_slow

rpt write_hdl                                          > $OUTPUTS_DIR/${TOP_MODULE}_netlist.v
rpt write_sdc -view $SIGNOFF_VIEW                      > $OUTPUTS_DIR/${TOP_MODULE}.sdc
rpt write_sdf -view $SIGNOFF_VIEW -timescale ns        > $OUTPUTS_DIR/${TOP_MODULE}.sdf
rpt write_db -common -all_root_attributes $OUTPUTS_DIR/${TOP_MODULE}.db

if {$WRITE_LEC} {
    file mkdir $OUTPUTS_DIR/conformal
    rpt write_hdl -lec                                 > $OUTPUTS_DIR/conformal/${TOP_MODULE}_lec.v
    rpt write_do_lec -golden_design rtl \
                     -revised $OUTPUTS_DIR/conformal/${TOP_MODULE}_lec.v \
                     -log_file $REPORTS_DIR/conformal_lec.log \
                     -tmp_dir $WORK_DIR -verbose \
                                                       > $OUTPUTS_DIR/conformal/${TOP_MODULE}_lec.do
}

################################################################################
# Place and route hand-off
# Everything Innovus needs: netlist, mmmc setup, libraries, physical config.
# Genus 23.1 dropped the -innovus flag, write_design only takes -base_name.
################################################################################

banner "Writing the Innovus hand-off"

file mkdir $OUTPUTS_DIR/innovus
write_design -base_name $OUTPUTS_DIR/innovus/${TOP_MODULE}

set handoff [glob -nocomplain $OUTPUTS_DIR/innovus/*]
if {[llength $handoff] == 0} {
    error "write_design wrote nothing to $OUTPUTS_DIR/innovus"
}
puts "Innovus hand-off: [llength $handoff] files in $OUTPUTS_DIR/innovus"

banner "Done - reports in $REPORTS_DIR, netlist in $OUTPUTS_DIR"

exit
