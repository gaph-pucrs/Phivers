vlib work
vmap work work

vlog ../TaskInjector/rtl/TaskInjectorPkg.sv
vlog ../TaskInjector/rtl/TaskInjector.sv
vlog ../RS5/rtl/RS5_pkg.sv
vlog ../RS5/rtl/mmu.sv
vlog ../RS5/rtl/fetch.sv
vlog ../RS5/rtl/decode.sv
vlog ../RS5/rtl/muldiv.sv
vlog ../RS5/rtl/execute.sv
vlog ../RS5/rtl/retire.sv
vlog ../RS5/rtl/regbank.sv
vlog ../RS5/rtl/CSRBank.sv
vlog ../RS5/rtl/RS5.sv
vlog ../RS5/rtl/plic.sv
vlog ../RS5/rtl/rtc.sv
vlog ../RingBuffer/rtl/RingBuffer.sv
vlog ../Hermes/rtl/HermesPkg.sv
vlog ../Hermes/rtl/HermesBuffer.sv
vlog ../Hermes/rtl/HermesCrossbar.sv
vlog ../Hermes/rtl/HermesSwitch.sv
vlog ../Hermes/rtl/HermesRouter.sv
vlog ../BrLite/rtl/BrLitePkg.sv
vlog ../BrLite/rtl/BrLiteRouter.sv
vlog ../DMNI/rtl/DMNIPkg.sv
vlog ../DMNI/rtl/DMA.sv
vlog ../DMNI/rtl/NI.sv
vlog ../DMNI/rtl/DMNI.sv
vlog ../rtl/PhiversPE.sv
vlog ../rtl/PhiversMC.sv

vlog ../RS5/sim/RAM_mem.sv
vlog ../TaskInjector/sim/MAParser.sv
vlog ../TaskInjector/sim/AppParser.sv
vlog PhiversPkg.sv
vlog PhiversTB.sv

vsim work.PhiversTB
