onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/instruction_address_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/instruction_i}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/decoder1/instruction_o}
add wave -noupdate -childformat {{{/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/RegFileFF_blk/regbankff/regfile[2]} -radix hexadecimal}} -subitemconfig {{/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/RegFileFF_blk/regbankff/regfile[2]} {-height 16 -radix hexadecimal}} {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/RegFileFF_blk/regbankff/regfile}
add wave -noupdate -divider -height 50 {New Divider}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/instruction_address}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mvmio}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mvmis}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mvmim}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/instruction_address_o}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mvmdo}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mvmds}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mvmdm}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mem_address_o}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mvmctl}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mmu_en}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mem_operation_enable_o}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mem_write_enable_o}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mem_data_o}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/instruction_i}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mmu_inst_fault}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mmu_data_fault}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mem_read_enable}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mem_write_enable}
add wave -noupdate {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/processor/mem_address}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {330010 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 216
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {329980 ns} {330113 ns}
