VOPT_TGT = work/$(TARGET)/_lib.qdb
VLOG_TGT = work/_lib.qdb

# -do "run -all; quit"
vsim:
	@mkdir -p debug
	@vsim -c work.$(TARGET) -suppress 3691 -quiet

# add +acc for waveform
$(VOPT_TGT): $(VLOG_TGT)
	@printf "${COR}Optimizing %s ... ${NC}\n" "$@"
	@vopt work.$(TOP) -o phivers -suppress 10587 -quiet

$(VLOG_TGT): $(SVSRC)
	@printf "${COR}Building %s ... ${NC}\n" "$@"
	@vlog $(SVSRC) -svinputport=relaxed -incr -suppress 13389 -quiet

clean-vsim:
	@rm -rf work

.PHONY: clean-vsim vsim
