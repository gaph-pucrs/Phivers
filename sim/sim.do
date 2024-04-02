vlib work
vmap work work

vlog ../TaskInjector/rtl/TaskInjectorPkg.sv -svinputport=relaxed
vlog ../TaskInjector/rtl/TaskInjector.sv -svinputport=relaxed
vlog ../RS5/rtl/RS5_pkg.sv -svinputport=relaxed
vlog ../RS5/rtl/mmu.sv -svinputport=relaxed
vlog ../RS5/rtl/fetch.sv -svinputport=relaxed
vlog ../RS5/rtl/decode.sv -svinputport=relaxed
vlog ../RS5/rtl/mul.sv -svinputport=relaxed
vlog ../RS5/rtl/div.sv -svinputport=relaxed
vlog ../RS5/rtl/execute.sv -svinputport=relaxed
vlog ../RS5/rtl/retire.sv -svinputport=relaxed
vlog ../RS5/rtl/regbank.sv -svinputport=relaxed
vlog ../RS5/rtl/CSRBank.sv -svinputport=relaxed
vlog ../RS5/rtl/RS5.sv -svinputport=relaxed
vlog ../RS5/rtl/plic.sv -svinputport=relaxed
vlog ../RS5/rtl/rtc.sv -svinputport=relaxed
vlog ../RingBuffer/rtl/RingBuffer.sv -svinputport=relaxed
vlog ../Hermes/rtl/HermesPkg.sv -svinputport=relaxed
vlog ../Hermes/rtl/HermesBuffer.sv -svinputport=relaxed
vlog ../Hermes/rtl/HermesCrossbar.sv -svinputport=relaxed
vlog ../Hermes/rtl/HermesSwitch.sv -svinputport=relaxed
vlog ../Hermes/rtl/HermesRouter.sv -svinputport=relaxed
vlog ../BrLite/rtl/BrLitePkg.sv -svinputport=relaxed
vlog ../BrLite/rtl/BrLiteRouter.sv -svinputport=relaxed
vlog ../DMNI/rtl/DMNIPkg.sv -svinputport=relaxed
vlog ../DMNI/rtl/DMA.sv -svinputport=relaxed
vlog ../DMNI/rtl/NI.sv -svinputport=relaxed
vlog ../DMNI/rtl/DMNI.sv -svinputport=relaxed

vlog Debug.sv -svinputport=relaxed
vlog ../rtl/PhiversPE.sv -svinputport=relaxed
vlog ../rtl/PhiversMC.sv -svinputport=relaxed

vlog ../RS5/sim/RAM_mem.sv -svinputport=relaxed
vlog ../TaskInjector/sim/MAParser.sv -svinputport=relaxed
vlog ../TaskInjector/sim/AppParser.sv -svinputport=relaxed
vlog PhiversPkg.sv -svinputport=relaxed
vlog PhiversTB.sv -svinputport=relaxed

vsim work.PhiversTB -voptargs=+acc

do wave.do 

