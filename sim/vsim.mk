VOPT_TGT = work/$(TARGET)/_lib.qdb
VLOG_TGT = work/_lib.qdb

vsim: $(VOPT_TGT)
	@mkdir -p debug
	@vsim -c work.$(TARGET) -do "run -all; quit" -suppress 3691

# add +acc for waveform
$(VOPT_TGT): $(VLOG_TGT)
	@vopt work.$(TOP) -o phivers -suppress 10587

$(VLOG_TGT): $(SVSRC)
	@vlog $(SVSRC) -svinputport=relaxed -incr -suppress 13389
