TARGET = phivers
TOP = PhiversTB

SVFLAGS =
SVSRC =

# Add TaskInjector
TASKINJECTOR = ../TaskInjector/rtl
SVSRC += $(wildcard $(TASKINJECTOR)/*.sv)
SVFLAGS += -I$(TASKINJECTOR) -I$(TASKINJECTOR)/../sim

# Add RS5
RS5 = ../RS5/rtl
SVSRC += $(wildcard $(RS5)/*.sv)
SVFLAGS += -I$(RS5) -I$(RS5)/../sim

# Add Ringbuffer
RINGBUFFER = ../RingBuffer/rtl
SVSRC += $(wildcard $(RINGBUFFER)/*.sv)
SVFLAGS += -I$(RINGBUFFER)

# Add Hermes
HERMES = ../Hermes/rtl
SVSRC += $(wildcard $(HERMES)/*.sv)
SVFLAGS += -I$(HERMES)

# Add BrLite
BRLITE = ../BrLite/rtl
SVSRC += $(wildcard $(BRLITE)/*.sv)
SVFLAGS += -I$(BRLITE)

# Add DMNI
DMNI = ../DMNI/rtl
SVSRC += $(wildcard $(DMNI)/*.sv)
SVFLAGS += -I$(DMNI)

# Add Phivers
PHIVERS = ../rtl
SVSRC += $(wildcard $(PHIVERS)/*.sv)
SVFLAGS += -I$(PHIVERS)

# Add simulation sources
SVSRC += \
	../RS5/sim/RAM_mem.sv \
	../TaskInjector/sim/MAParser.sv \
	../TaskInjector/sim/AppParser.sv \
	Debug.sv \
	PhiversPkg.sv \
	PhiversTB.sv

include verilator.mk
include vsim.mk

default: verilator
