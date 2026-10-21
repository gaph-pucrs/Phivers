VERILATOR = verilator

OBJ_DIR = obj_dir

OPT      = -fdata-sections -ffunction-sections -flto
OPT_FAST = -O3
SVOPT    = --x-initial fast --noassert

ifeq ($(TRACE), 1)
	TRACE_VERILATOR = --trace-fst -GTRACE=1
endif

MAKEFLAGS_VERILATOR = -MAKEFLAGS AR=gcc-ar -MAKEFLAGS "'OPT_FAST=$(OPT_FAST)'" -MAKEFLAGS "'OPT=$(OPT)'"
LDFLAGS_VERILATOR   = -LDFLAGS "-flto=auto -Wl,--gc-sections"
VERILATE_FLAGS = -Wall --quiet --autoflush --binary --build-jobs 0 --timescale 1ns/1ns -o ../$(TARGET) $(SVOPT) $(TRACE_VERILATOR) $(MAKEFLAGS_VERILATOR) $(LDFLAGS_VERILATOR)

$(TARGET): $(SVSRC)
	@printf "${COR}Verilating %s ... ${NC}\n" "$(TOP)"
	@$(VERILATOR) --top $(TOP) $(SVSRC) $(SVFLAGS) $(VERILATE_FLAGS)

clean-verilator:
	@rm -rf $(OBJ_DIR)
	@rm -f $(TARGET)
	@rm -f trace.fst

.PHONY: clean-verilator
