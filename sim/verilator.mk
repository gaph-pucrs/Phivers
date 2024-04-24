VERILATOR = verilator

OBJ_DIR = obj_dir

ifeq ($(TRACE), 1)
	TRACE_VERILATOR = --trace-fst
	DEF_TRACE = -DTRACE_VERILATOR=1
endif

verilator:
	@mkdir -p debug
	@./$(TARGET)

$(TARGET): $(SVSRC)
	@printf "${COR}Building %s ... ${NC}\n" "$@"
	@$(VERILATOR) --quiet --binary -j 0 -Wall $(SVSRC) $(SVFLAGS) --autoflush -o ../phivers $(TRACE_VERILATOR) $(DEF_TRACE) --timescale 1ns/1ns

clean-verilator:
	@rm -rf $(OBJ_DIR)
	@rm -f $(TARGET)
	@rm -f trace.fst

.PHONY: clean-verilator verilator
