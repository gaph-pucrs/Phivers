VERILATOR = verilator

OBJ_DIR = obj_dir
OBJ = $(patsubst %.cpp, $(OBJ_DIR)/%.o, $(SIMTOP).cpp)

OPT      = -fdata-sections -ffunction-sections -flto
OPT_FAST = -O3
SVOPT    = --x-initial fast --noassert

ifeq ($(TRACE), 1)
	TRACE_VERILATOR = --trace-fst
	DEF_TRACE = -DTRACE=1
	LD_TRACE = -lz
endif

CPPFLAGS = $(OPT) $(OPT_FAST) `pkgconf --cflags verilator` $(DEF_TRACE)
LDFLAGS = -lpthread -Wl,--gc-sections,-flto $(LD_TRACE)
VERILATE_FLAGS = -Wall --quiet --autoflush --cc --timescale 1ns/1ns $(SVOPT) $(TRACE_VERILATOR)

$(TARGET): $(OBJ) $(OBJ_DIR)/V$(TOP)__ALL.a
	@printf "${COR}Linking %s ... ${NC}\n" "$@"
	@g++ $(OBJ) $(OBJ_DIR)/*.a -o $@ $(LDFLAGS)

$(OBJ_DIR)/%.o: %.cpp $(OBJ_DIR)/V$(TOP).cpp
	@printf "${COR}Compiling %s ... ${NC}\n" "$<"
	@g++ -c $< -o $@ -I$(OBJ_DIR) $(CPPFLAGS)

$(OBJ_DIR)/V$(TOP).cpp: $(SVSRC)
	@printf "${COR}Verilating %s ... ${NC}\n" "$(TOP)"
	@$(VERILATOR) --top $(TOP) $(SVSRC) $(SVFLAGS) $(VERILATE_FLAGS)

$(OBJ_DIR)/V$(TOP)__ALL.a: $(OBJ_DIR)/V$(TOP).cpp
	@printf "${COR}Compiling %s ... ${NC}\n" "$@"
	@+make AR=gcc-ar OPT_FAST="$(OPT_FAST)" OPT="$(OPT)" -C $(OBJ_DIR) -f V$(TOP).mk -s

clean-verilator:
	@rm -rf $(OBJ_DIR)
	@rm -f $(TARGET)
	@rm -f trace.fst

.PHONY: clean-verilator
