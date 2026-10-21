VOPT_TGT = work/$(TARGET)/_lib.qdb
VLOG_TGT = work/_lib.qdb

ifeq ($(TRACE), 1)
	VOPT_TRACE = +acc
else
	VSIM_CMDLINE = -c
	RUN_CMDLINE = -do "run -all; quit"
endif

vsim:
	@mkdir -p debug
	@vsim $(VSIM_CMDLINE) work.$(TARGET) -suppress 3691 -quiet $(SIM_TIMEOUT) $(RUN_CMDLINE)

$(VOPT_TGT): $(VLOG_TGT)
	@printf "${COR}Optimizing %s ... ${NC}\n" "$@"
	@vopt work.$(TOP) -o $(TARGET) -suppress 10587 -quiet $(VOPT_TRACE)

$(VLOG_TGT): $(SVSRC)
	@printf "${COR}Building %s ... ${NC}\n" "$@"
	@vlog $(SVSRC) -svinputport=relaxed -incr -suppress 13389 -quiet

clean-vsim:
	@rm -rf work

.PHONY: clean-vsim vsim
