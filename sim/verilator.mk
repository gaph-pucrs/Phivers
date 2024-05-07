VERILATOR = verilator

OBJ_DIR = obj_dir
OBJ = $(patsubst %.cpp, $(OBJ_DIR)/%.o, $(CPPTOP))

SVOPT    = --x-initial fast --noassert -O3
CFLAGS   = -ffunction-sections -fdata-sections -flto
LDFLAGS  = -Wl,--gc-sections -flto

ifeq ($(TRACE), 1)
	TRACE_VERILATOR = --trace-fst
	DEF_TRACE = -DTRACE=1
endif

VERILATE_FLAGS = -Wall --quiet --autoflush --timescale 1ns/1ns -CFLAGS "$(CFLAGS)" -LDFLAGS "$(LDFLAGS)" $(SVOPT) $(TRACE_VERILATOR)

verilator:
	@mkdir -p debug
	@./$(TARGET)

$(TARGET): $(SVSRC)
	@printf "${COR}Building %s ... ${NC}\n" "$@"
	@+verilator --binary $(SVSRC) --top $(TOP) $(SVFLAGS) $(VERILATE_FLAGS) -MAKEFLAGS -s -o ../$@

clean-verilator:
	@rm -rf $(OBJ_DIR)
	@rm -f $(TARGET)
	@rm -f trace.fst

.PHONY: clean-verilator verilator
