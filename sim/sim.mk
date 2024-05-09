TARGET = phivers

ifeq ($(TRACE), 1)
	VSIM_WAVE = -do wave.do
else
	VSIM_CMDLINE = -c
	RUN_CMDLINE = -do "run -all; quit"
endif

verilator:
	@mkdir -p debug
	@../Phivers/sim/$(TARGET)

vsim:
	@mkdir -p debug
	@vsim $(VSIM_CMDLINE) ../Phivers/sim/work.$(TARGET) -suppress 3691 -quiet $(RUN_CMDLINE) $(VSIM_WAVE)

clean:
	@rm -rf debug
	@rm -rf log

.PHONY: verilator vsim clean
