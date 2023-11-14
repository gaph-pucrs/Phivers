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
add wave -noupdate -divider -height 50 {New Divider}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_en_i}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_we_i}
add wave -noupdate -radix hexadecimal -childformat {{{/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[4]} -radix hexadecimal} {{/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[3]} -radix hexadecimal} {{/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[2]} -radix hexadecimal} {{/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[1]} -radix hexadecimal} {{/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[0]} -radix hexadecimal}} -subitemconfig {{/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[4]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[3]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[2]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[1]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i[0]} {-height 16 -radix hexadecimal}} {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_addr_i}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_data_i}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/cfg_data_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/mem_we_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/mem_addr_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/mem_data_i}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/mem_data_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/noc_rx_i}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/noc_credit_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/noc_data_i}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/noc_tx_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/noc_credit_i}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/noc_data_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/ni/hermes_start_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/ni/hermes_operation_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/ni/hermes_size_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/ni/hermes_size_2_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/ni/hermes_address_o}
add wave -noupdate -radix hexadecimal {/PhiversTB/mc/gen_x[0]/gen_y[0]/pe/dmni/ni/hermes_address_2_o}
add wave -noupdate -divider -height 50 {New Divider}
add wave -noupdate /PhiversTB/ma_src/tx_o
add wave -noupdate /PhiversTB/ma_src/credit_i
add wave -noupdate /PhiversTB/ma_src/data_o
add wave -noupdate -divider -height 50 {New Divider}
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/src_rx_i
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/src_credit_o
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/src_data_i
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/noc_tx_o
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/noc_credit_i
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/noc_data_o
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/noc_rx_i
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/noc_credit_o
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/noc_data_i
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/inject_state
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/send_state
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/receive_state
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/in_header
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/in_payload
add wave -noupdate -radix hexadecimal -childformat {{{/PhiversTB/mc/MAInjector/out_header[12]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[11]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[10]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[9]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[8]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[7]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[6]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[5]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[4]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[3]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[2]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[1]} -radix hexadecimal} {{/PhiversTB/mc/MAInjector/out_header[0]} -radix hexadecimal}} -expand -subitemconfig {{/PhiversTB/mc/MAInjector/out_header[12]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[11]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[10]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[9]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[8]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[7]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[6]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[5]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[4]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[3]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[2]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[1]} {-height 16 -radix hexadecimal} {/PhiversTB/mc/MAInjector/out_header[0]} {-height 16 -radix hexadecimal}} /PhiversTB/mc/MAInjector/out_header
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/out_sent_cnt
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/out_header_idx
add wave -noupdate -radix hexadecimal /PhiversTB/mc/MAInjector/aux_header_idx
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {920832 ps} 0}
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
WaveRestoreZoom {920813 ps} {920971 ps}
