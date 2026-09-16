################################################################################
# Phivers - synthesis of a single PE (PhiversPE) with Cadence Genus
#
#   module load ddi/231      # or: module load wimed
#   make synth               # full flow at the default period
#   make synth PERIOD=2.5    # different target period
#   make elab                # stop right after elaboration (RTL debug)
#   make shell               # interactive Genus with the setup already sourced
#
# Everything is written under work/<run>, reports/<run> and outputs/<run>.
################################################################################

TOP         := PhiversPE
PERIOD      ?= 2.0
VECTOR      ?= 0
VLEN        ?= 128
CONFIG      := $(if $(filter-out 0,$(VECTOR)),v$(VLEN),scalar)
RUN         ?= $(TOP)_$(CONFIG)_$(subst .,p,$(PERIOD))ns

GENUS       ?= genus
GENUS_FLAGS ?= -overwrite -no_gui -abort_on_error

SYNTH_DIR   := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
REPO_DIR    := $(abspath $(SYNTH_DIR)/..)
PATCH_DIR   := $(SYNTH_DIR)/patches
SCRIPTS_DIR := $(SYNTH_DIR)/scripts
RUN_DIR     := $(SYNTH_DIR)/work/$(RUN)
REPORT_DIR  := $(SYNTH_DIR)/reports/$(RUN)
OUTPUT_DIR  := $(SYNTH_DIR)/outputs/$(RUN)

# Knobs read by scripts/setup.tcl. Unset ones fall back to the Tcl defaults.
export SYNTH_DIR
export PERIOD RUN
export VECTOR VLEN
export CPUS EFFORT POWER_EFFORT CLOCK_GATING ERROR_ON_LATCH
export RETIME PHYSICAL LEC STOP_AFTER PDK_ROOT

.PHONY: help synth elab generic shell reports export patch unpatch clean distclean

# <patch name>:<directory it applies to>
RTL_PATCHES := Phivers:. BrLite:BrLite DMNI:DMNI

help:
	@echo "Phivers PE synthesis (Genus)"
	@echo ""
	@echo "  make synth                 full flow        (run: $(RUN))"
	@echo "  make elab                  stop after elaboration"
	@echo "  make generic               stop after generic synthesis"
	@echo "  make shell                 interactive Genus session"
	@echo "  make reports               show the QoR summary of the last run"
	@echo "  make export                re-write the Innovus hand-off from the .db"
	@echo "  make patch / unpatch       (un)apply the RTL synthesisability fixes"
	@echo "  make clean                 remove work/"
	@echo "  make distclean             remove work/, reports/ and outputs/"
	@echo ""
	@echo "Knobs (make <target> KNOB=value):"
	@echo "  PERIOD=2.0                 clock period in ns"
	@echo "  VECTOR=0                   1 enables the RS5 vector unit"
	@echo "  VLEN=128                   vector register width, multiple of 32"
	@echo "  RUN=<name>                 run name (default derived from PERIOD)"
	@echo "  EFFORT=high                syn_global_effort: low|medium|high"
	@echo "  CPUS=8                     parallel CPUs"
	@echo "  CLOCK_GATING=true          insert clock gates"
	@echo "  ERROR_ON_LATCH=false       abort when a latch is inferred"
	@echo "  RETIME=false               enable register retiming"
	@echo "  PHYSICAL=true              physical-aware (LEF + PLE) synthesis"
	@echo "  LEC=false                  write the Conformal dofile"

# Genus reads its command file incrementally, so editing scripts/ while a run is
# in flight makes it jump to the wrong offset and re-execute earlier steps. Each
# run therefore works from its own snapshot, which also records exactly which
# scripts produced the results.
synth: | $(RUN_DIR)
	@rm -rf $(RUN_DIR)/scripts && cp -r $(SCRIPTS_DIR) $(RUN_DIR)/scripts
	cd $(RUN_DIR) && $(GENUS) $(GENUS_FLAGS) -log genus -files $(RUN_DIR)/scripts/synth.tcl

elab: STOP_AFTER := elaborate
elab: synth

generic: STOP_AFTER := generic
generic: synth

shell: | $(RUN_DIR)
	cd $(RUN_DIR) && $(GENUS) -log genus_shell -overwrite \
		-execute "source $(SCRIPTS_DIR)/setup.tcl; source \$$SCRIPTS_DIR/reports.tcl"

export: | $(RUN_DIR)
	cd $(RUN_DIR) && $(GENUS) $(GENUS_FLAGS) -log genus_export -files $(SCRIPTS_DIR)/export.tcl

reports:
	@test -d $(REPORT_DIR) || { echo "no reports for run $(RUN)"; exit 1; }
	@echo "== $(REPORT_DIR)"; \
	 cat $(REPORT_DIR)/final/qor.rpt 2>/dev/null

$(RUN_DIR):
	@mkdir -p $@

clean:
	rm -rf $(SYNTH_DIR)/work

distclean: clean
	rm -rf $(SYNTH_DIR)/reports $(SYNTH_DIR)/outputs
