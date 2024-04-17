VERILATOR = verilator

OBJ_DIR = obj_dir

verilator: $(TARGET)

$(TARGET): $(OBJ_DIR)/V$(TOP)
	cp $(OBJ_DIR)/V$(TOP) $(TARGET)

$(OBJ_DIR)/V$(TOP): $(SVSRC)
	$(VERILATOR) --binary -j 0 -Wall $(TOP).sv $(SVFLAGS)

sim: $(TARGET)
	mkdir -p debug
	./$(TARGET)

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(TARGET)

.PHONY: clean verilator vsim
.PHONY: $(OBJ_DIR)/V$(TOP)
