################################################################################
# Phivers - single PE synthesis (Cadence Genus)
#
# Environment and configuration. Sourced by synth.tcl and by views.mmmc, so it
# must be idempotent and must not depend on the current working directory.
################################################################################

if {[info exists ::PHIVERS_SETUP_DONE]} {
    return
}
set ::PHIVERS_SETUP_DONE 1

################################################################################
# Directories (derived from this script's location - nothing is hardcoded)
################################################################################

if {[info script] ne ""} {
    set SCRIPTS_DIR [file normalize [file dirname [info script]]]
} else {
    set SCRIPTS_DIR $env(PHIVERS_SCRIPTS_DIR)
}
# The Makefile runs Genus on a snapshot of scripts/ inside the run directory, so
# the flow cannot be derived from the script location alone: it passes the real
# synth/ directory in the environment.
if {[info exists env(SYNTH_DIR)] && $env(SYNTH_DIR) ne ""} {
    set SYNTH_DIR [file normalize $env(SYNTH_DIR)]
} else {
    set SYNTH_DIR [file dirname $SCRIPTS_DIR]
}
set PHIVERS_DIR [file dirname $SYNTH_DIR]

# Exported so that files read by the tool (views.mmmc, rtl.f) can find the flow
set env(PHIVERS_SCRIPTS_DIR) $SCRIPTS_DIR
set env(PHIVERS_DIR)         $PHIVERS_DIR

# Returns $env(NAME) if set and non-empty, $default otherwise.
# Every knob below can therefore be overridden from the Makefile command line.
proc opt {name default} {
    global env
    if {[info exists env($name)] && [string trim $env($name)] ne ""} {
        return [string trim $env($name)]
    }
    return $default
}

################################################################################
# Design configuration
################################################################################

set TOP_MODULE   PhiversPE
set CLK_PORT     clk_i
set RST_PORT     rst_ni
set CLK_NAME     clk

# Target period in ns (2.0 ns = 500 MHz). Override with: make synth PERIOD=2.5
set CLK_PERIOD   [opt PERIOD 2.0]

# Vector unit (RS5 "V" extension), off in the RTL by default.
#   make synth VECTOR=1            vector unit, VLEN=128
#   make synth VECTOR=1 VLEN=256   wider vector registers
set VECTOR [opt VECTOR 0]
set VLEN   [opt VLEN   128]

# VLEN is the vector register width in bits. The unit slices each register into
# 8/16/32 bit elements (VLENB = VLEN/8, and VLENB/4 has to be at least 1), so
# anything that is not a multiple of 32 does not elaborate.
if {$VECTOR && ($VLEN < 32 || $VLEN % 32 != 0)} {
    error "VLEN=$VLEN is not usable: it must be a multiple of 32, at least 32"
}

set CONFIG_NAME [expr {$VECTOR ? "v$VLEN" : "scalar"}]

# Top level parameter overrides, as {name value} pairs. The simulation-only
# debug blocks are neutralised by rtl/debug_stubs.sv, so only the vector
# configuration ever needs to be overridden here.
set DESIGN_PARAMS {}
if {$VECTOR} {
    lappend DESIGN_PARAMS [list VEnable 1] [list VLEN $VLEN]
}

# Name of this run: reports and outputs are kept per run so that period sweeps
# do not overwrite each other.
set RUN_NAME     [opt RUN "${TOP_MODULE}_${CONFIG_NAME}_[string map {. p} ${CLK_PERIOD}]ns"]

set WORK_DIR     [pwd]
set REPORTS_DIR  $SYNTH_DIR/reports/$RUN_NAME
set OUTPUTS_DIR  $SYNTH_DIR/outputs/$RUN_NAME

################################################################################
# Flow knobs
################################################################################

set NUM_CPUS         [opt CPUS           8]
set SYN_EFFORT       [opt EFFORT         high]     ;# low | medium | high
set POWER_EFFORT     [opt POWER_EFFORT   high]
set CLOCK_GATING     [opt CLOCK_GATING   true]
set ERROR_ON_LATCH   [opt ERROR_ON_LATCH true]     ;# abort when a latch is inferred
set RETIME           [opt RETIME         false]    ;# register retiming
set PHYSICAL         [opt PHYSICAL       true]     ;# read LEF + physical-aware synthesis
set WRITE_LEC        [opt LEC            false]    ;# emit Conformal dofile

################################################################################
# Technology - TSMC 28 HPC+ (tcbn28hpcplusbwp30p140)
#
# Block-level synthesis: standard cells only. IO pads belong to the chip top
# level (PhiversMC / full NoC), not to a single PE.
################################################################################

set PDK_ROOT   [opt PDK_ROOT /pdk/tsmc/PDK28/PDK_TSMC28_bv/tcbn28hpcplusbwp30p140_190a/TSMCHOME/digital]
set LIB_PATH   $PDK_ROOT/Front_End
set TECH_PATH  $PDK_ROOT/Back_End

set LIB_VER    tcbn28hpcplusbwp30p140_180a       ;# .lib version under timing_power_noise/CCS
set AOCV_VER   tcbn28hpcplusbwp30p140_190a       ;# .aocvm version under SBOCV/CCS
set LEF_VER    tcbn28hpcplusbwp30p140_110a       ;# .lef version under Back_End/lef

set TIMING_DIR $LIB_PATH/timing_power_noise/CCS/$LIB_VER
set AOCV_DIR   $LIB_PATH/SBOCV/CCS/$AOCV_VER
set LEF_DIR    $TECH_PATH/lef
set QRC_DIR    $TECH_PATH/qrc

set TECH_LEF   $LEF_DIR/tsmcn28_9lm5X1Y1Z1UUTRDL.tlef
set STDCELL_LEF $LEF_DIR/$LEF_VER/lef/tcbn28hpcplusbwp30p140.lef

# Cell used to model the environment driving the block inputs
set DRIVING_CELL BUFFD4BWP30P140
set DRIVING_PIN  Z
