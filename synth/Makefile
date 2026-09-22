################################################################################
# Phivers - synthesis of a single PE (PhiversPE) with Cadence Genus
#
#   module load ddi/231
#   make                            scalar PE at 2.0 ns
#   make VECTOR=1                   with the RS5 vector unit, VLEN=128
#   make PERIOD=1.5 EFFORT=medium   any knob below, on the command line
#
# Results go to reports/<run>/ and outputs/<run>/, where <run> is derived from
# the configuration, so runs never overwrite each other. See README.md.
################################################################################

.DEFAULT_GOAL := synth

################################################################################
# What to build
#
#   PERIOD   clock period in ns (2.0 = 500 MHz)
#   VECTOR   1 enables the RS5 vector unit
#   VLEN     vector register width in bits, a multiple of 32
################################################################################

PERIOD         ?= 2.0
VECTOR         ?= 0
VLEN           ?= 128

################################################################################
# How to build it
#
#   CPUS            parallel CPUs
#   EFFORT          syn_global_effort: low | medium | high
#   POWER_EFFORT    design_power_effort
#   CLOCK_GATING    insert integrated clock gates
#   ERROR_ON_LATCH  abort when a latch is inferred
#   RETIME          register retiming
#   PHYSICAL        physical-aware synthesis (reads the LEF, uses PLE)
#   LEC             also write the Conformal dofile
################################################################################

CPUS           ?= 8
EFFORT         ?= high
POWER_EFFORT   ?= high
CLOCK_GATING   ?= true
ERROR_ON_LATCH ?= true
RETIME         ?= false
PHYSICAL       ?= true
LEC            ?= false

# scripts/setup.tcl reads all of these; an empty one falls back to its default.
export PERIOD VECTOR VLEN CPUS EFFORT POWER_EFFORT CLOCK_GATING
export ERROR_ON_LATCH RETIME PHYSICAL LEC SYNTH_DIR

################################################################################
# Paths and run name
################################################################################

TOP         := PhiversPE
CONFIG      := $(if $(filter-out 0,$(VECTOR)),v$(VLEN),scalar)
RUN         ?= $(TOP)_$(CONFIG)_$(subst .,p,$(PERIOD))ns

SYNTH_DIR   := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SCRIPTS_DIR := $(SYNTH_DIR)/scripts
RUN_DIR     := $(SYNTH_DIR)/work/$(RUN)

GENUS       ?= genus
GENUS_FLAGS ?= -overwrite -no_gui -abort_on_error

.PHONY: synth clean distclean

################################################################################
# Synthesis
#
# Genus reads its command file incrementally, so editing scripts/ while a run is
# in flight makes it resume at the wrong offset and re-execute earlier steps.
# Each run works from its own snapshot, which also records exactly which scripts
# produced the results. synth.tcl writes the Innovus hand-off itself, at the end.
################################################################################

synth: | $(RUN_DIR)
	@rm -rf $(RUN_DIR)/scripts
	@cp -r $(SCRIPTS_DIR) $(RUN_DIR)/scripts
	cd $(RUN_DIR) && $(GENUS) $(GENUS_FLAGS) -log genus -files $(RUN_DIR)/scripts/synth.tcl

$(RUN_DIR):
	@mkdir -p $@

################################################################################
# Cleaning
################################################################################

clean:
	rm -rf $(SYNTH_DIR)/work

distclean: clean
	rm -rf $(SYNTH_DIR)/reports $(SYNTH_DIR)/outputs
