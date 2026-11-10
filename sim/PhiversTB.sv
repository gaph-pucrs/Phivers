`include "../RS5/rtl/RS5_pkg.sv"
`include "PhiversPkg.sv"

module PhiversTB
    import RS5_pkg::*;
    import PhiversPkg::*;
#(
    parameter bit TRACE = 0
)
();

    timeunit 1ns;
    timeprecision 1ns;

    logic clk;
    logic rst_n;

    initial begin
        clk = 1'b0;
        forever #5 clk = !clk;
    end

    initial begin
        rst_n = 1'b0;
        #100 rst_n = 1'b1;
    end

    /* +timeout=<ms>: 0 or absent runs until $finish */
    initial begin
        int unsigned timeout;
        if ($value$plusargs("timeout=%d", timeout) && timeout != 0) begin
            $display("Simulating until %0dms", timeout);
            repeat (timeout) #1ms;
            $display("\nSimulation ending due to timeout");
            $finish();
        end
    end

    if (TRACE) begin : gen_trace
        initial begin
            $dumpfile("trace.fst");
            $dumpvars();
        end
    end

    final $display("\nSimulation time: %0.3fms", $realtime / 1ms);

    logic [15:0] mapper_address;
    
    logic        ma_src_rx;
    logic        ma_src_credit;
    logic [31:0] ma_src_data;

    logic        eoa;
    logic        app_src_rx;
    logic        app_src_credit;
    logic [31:0] app_src_data;

    logic        imem_enable     [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [29:0] imem_addr       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] imem_data       [(N_PE_X - 1):0][(N_PE_Y - 1):0];

    logic        mem_en          [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [3:0]  mem_we          [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [29:0] mem_addr        [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] mem_data_read   [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] mem_data_write  [(N_PE_X - 1):0][(N_PE_Y - 1):0];

//////////////////////////////////////////////////////////////////////////////
// Many Core
//////////////////////////////////////////////////////////////////////////////

    PhiversMC #(
        .N_PE_X        (N_PE_X       ),
        .N_PE_Y        (N_PE_Y       ),
        .TASKS_PER_PE  (TASKS_PER_PE ),
        .PAGE_SZ       (PAGE_SZ      ),
        .ADDR_MA_INJ   (ADDR_MA_INJ  ),
        .PORT_MA_INJ   (PORT_MA_INJ  ),
        .ADDR_APP_INJ  (ADDR_APP_INJ ),
        .PORT_APP_INJ  (PORT_APP_INJ ),
        .Environment   (ASIC         ),
        .LINK_CFG      (LINK_CFG     ),
        .UART_DEBUG    (UART_DEBUG   ),
        .SCHED_DEBUG   (SCHED_DEBUG  ),
        .PIPE_DEBUG    (PIPE_DEBUG   ),
        .TRAFFIC_DEBUG (TRAFFIC_DEBUG),
        .DMNI_DEBUG    (DMNI_DEBUG   ),
        .SAFE_DEBUG    (SAFE_DEBUG   ),
        .VEnable       (VEnable      ),
        .VLEN          (VLEN         )
    )
    mc (
        .clk_i            (clk            ),
        .rst_ni           (rst_n          ),
        .mapper_address_i (mapper_address ),
        .ma_src_rx_i      (ma_src_rx      ),
        .ma_src_credit_o  (ma_src_credit  ),
        .ma_src_data_i    (ma_src_data    ),
        .app_src_eoa_i    (eoa            ),
        .app_src_rx_i     (app_src_rx     ),
        .app_src_credit_o (app_src_credit ),
        .app_src_data_i   (app_src_data   ),
        .imem_enable_o    (imem_enable    ),
        .imem_addr_o      (imem_addr      ),
        .imem_data_i      (imem_data      ),
        .mem_en_o         (mem_en         ),
        .mem_we_o         (mem_we         ),
        .mem_addr_o       (mem_addr       ),
        .mem_data_i       (mem_data_read  ),
        .mem_data_o       (mem_data_write )
    );

    /* Macros, not parameters: Verilator applies a bind even inside a false generate if */
`ifdef RS5_DEBUG
    bind regbank RegbankDebug debug();
    bind CSRBank HPMProfiler report();
`endif

`ifdef RAM_DEBUG
    bind RAM_mem MemDebug debug();
`endif

//////////////////////////////////////////////////////////////////////////////
// Memory
//////////////////////////////////////////////////////////////////////////////

    localparam MEM_SZ = PAGE_SZ * (TASKS_PER_PE + 1);
    localparam KERNEL = "../MAestro/kernel.bin";

    generate
        for (genvar x = 0; x < N_PE_X; x++) begin : gen_pe_x
            for (genvar y = 0; y < N_PE_Y; y++) begin : gen_pe_y
                /* Port A: instruction fetch. Port B: load/store and DMA. */
                RamArray #(
                    .MEM_WIDTH  (IMEM_SZ                                 ),
                    .BIN_FILE   (KERNEL_TEXT                             )
                MEM (
                    .clk        (clk                                   ),

                    .enA_i      (imem_enable   [x][y]                  ), 
                    .weA_i      (4'h0                                  ), 
                    .addrA_i    (imem_addr     [x][y][($clog2(MEM_SZ) - 1):0]), 
                    .dataA_i    (32'h0                                 ), 
                    .dataA_o    (imem_data     [x][y]                  ),

                    .enB_i      (mem_en        [x][y]                  ), 
                    .weB_i      (mem_we        [x][y]                  ), 
                    .addrB_i    (mem_addr      [x][y][($clog2(MEM_SZ) - 1):0]), 
                    .dataB_i    (mem_data_write[x][y]                  ), 
                    .dataB_o    (mem_data_read [x][y]                  )
                );

                if (MEM_PROFILE) begin : gen_mem_profile
                    MemProfile #(
                        .MEM_SZ   (MEM_SZ               ),
                        .PAGE_SZ  (PAGE_SZ              ),
                        .BLOCK_SZ (MEM_PROFILE_BLOCK    ),
                        .ADDRESS  (16'(x << 8) | 16'(y) ),
                        .MEM_NAME ("M"                  )
                    )
                    mem_profile (
                        .clk     (clk              ),
                        .enA_i   (imem_enable[x][y]),
                        .addrA_i (imem_addr  [x][y]),
                        .enB_i   (mem_en     [x][y]),
                        .addrB_i (mem_addr   [x][y])
                    );
                end
            end
        end
    endgenerate

//////////////////////////////////////////////////////////////////////////////
// INJECTORS
//////////////////////////////////////////////////////////////////////////////

    /* verilator lint_off UNUSEDSIGNAL */
    logic           ma_eoa;
    logic [15:0]    app_mapper_address;
    /* verilator lint_on UNUSEDSIGNAL */

    TaskParser #(
        .FLIT_SIZE    (32             ),
        .INJECT_MAPPER(1              ),
        .START_FILE   ("ma_start.txt" ),
        .APP_PATH     ("../management")
    )
    ma_src (
        .clk_i            (clk           ),
        .rst_ni           (rst_n         ),
        .eoa_o            (ma_eoa        ),
        .tx_o             (ma_src_rx     ),
        .credit_i         (ma_src_credit ),
        .data_o           (ma_src_data   ),
        .mapper_address_o (mapper_address)
    );

    TaskParser #(
        .FLIT_SIZE    (32               ),
        .INJECT_MAPPER(0                ),
        .START_FILE   ("app_start.txt"  ),
        .APP_PATH     ("../applications")
    )
    app_src (
        .clk_i            (clk               ),
        .rst_ni           (rst_n             ),
        .eoa_o            (eoa               ),
        .tx_o             (app_src_rx        ),
        .credit_i         (app_src_credit    ),
        .data_o           (app_src_data      ),
        .mapper_address_o (app_mapper_address)
    );

endmodule
