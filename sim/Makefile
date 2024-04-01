VERILATOR = verilator

SVSRC =

# Add TaskInjector
TASKINJECTOR = ../TaskInjector/rtl
SVSRC += $(wildcard $(TASKINJECTOR)/*.sv)

# Add RS5
RS5 = ../RS5/rtl
SVSRC += $(wildcard $(RS5)/*.sv)

# Add Ringbuffer
RINGBUFFER = ../RingBuffer/rtl
SVSRC += $(wildcard $(RINGBUFFER)/*.sv)

# Add Hermes
HERMES = ../Hermes/rtl
SVSRC += $(wildcard $(HERMES)/*.sv)

# Add BrLite
BRLITE = ../BrLite/rtl
SVSRC += $(wildcard $(BRLITE)/*.sv)

# Add DMNI
DMNI = ../DMNI/rtl
SVSRC += $(wildcard $(DMNI)/*.sv)

# Add Phivers
PHIVERS = ../rtl
SVSRC += $(wildcard $(PHIVERS)/*.sv)

# Add simulation sources
SVSRC += \
	../RS5/sim/RAM_mem.sv \
	../TaskInjector/sim/MAParser.sv \
	../TaskInjector/sim/AppParser.sv \
	Debug.sv \
	PhiversPkg.sv \
	PhiversTB.sv

default: verilate

verilate: $(SVSRC)
	$(VERILATOR) --binary -j 0 -Wall $^

