COR  =\033[0;32m
NC   =\033[0m # No Color

TARGET = phivers
TOP = PhiversTB
CPPTOP = TopTB.cpp

TRACE ?= 0
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
	../TaskInjector/sim/TaskParser.sv \
	Debug.sv \
	TrafficRouter.sv \
	TrafficBroadcast.sv \
	PhiversTB.sv

default: $(TARGET)

include verilator.mk
include vsim.mk

clean: clean-verilator clean-vsim
	@rm -rf debug
	@rm -rf log

.PHONY: default clean
