VERILATOR = verilator

OBJ_DIR = obj_dir

sim:
	@mkdir -p debug
	@./$(TARGET)

$(OBJ_DIR)/V$(TOP): $(SVSRC)
	@printf "${COR}Building %s ... ${NC}\n" "$@"
	@$(VERILATOR) --binary -j 0 -Wall $(SVSRC) $(SVFLAGS)

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(TARGET)

.PHONY: clean verilator vsim
.PHONY: $(OBJ_DIR)/V$(TOP)
