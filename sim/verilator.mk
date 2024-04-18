VERILATOR = verilator

OBJ_DIR = obj_dir

verilator:
	@mkdir -p debug
	@./$(TARGET)

$(TARGET): $(SVSRC)
	@printf "${COR}Building %s ... ${NC}\n" "$@"
	@$(VERILATOR) --quiet --binary -j 0 -Wall $(SVSRC) $(SVFLAGS) --autoflush -o ../phivers

clean-verilator:
	@rm -rf $(OBJ_DIR)
	@rm -f $(TARGET)

.PHONY: clean-verilator verilator
