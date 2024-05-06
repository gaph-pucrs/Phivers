`include "../RS5/rtl/RS5_pkg.sv"
`include "PhiversPkg.sv"

module PhiversTB
    import RS5_pkg::*;
    import PhiversPkg::*;
(
);

    logic clk = 1'b1;
    logic rst_n;

    always begin
        #5.0 clk <= 0;
        #5.0 clk <= 1;
        `ifdef TRACE_VERILATOR
            $dumpvars;
        `endif
    end

    initial begin
        `ifdef TRACE_VERILATOR
            $dumpfile("trace.fst");
        `endif

        rst_n = 1'b0;
        
        #100 rst_n = 1'b1;
    end

    logic [15:0] mapper_address;
    
    logic        ma_src_rx;
    logic        ma_src_credit;
    logic [31:0] ma_src_data;

    logic        eoa;
    logic        app_src_rx;
    logic        app_src_credit;
    logic [31:0] app_src_data;

    logic [23:0] imem_addr       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] imem_data       [(N_PE_X - 1):0][(N_PE_Y - 1):0];

    logic        dmem_en         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [3:0]  dmem_we         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [23:0] dmem_addr       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] dmem_data_read  [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] dmem_data_write [(N_PE_X - 1):0][(N_PE_Y - 1):0];

    logic        idma_en         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        ddma_en         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [3:0]  dma_we          [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [23:0] dma_addr        [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] idma_data       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] ddma_data       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] dma_data        [(N_PE_X - 1):0][(N_PE_Y - 1):0];

//////////////////////////////////////////////////////////////////////////////
// Many Core
//////////////////////////////////////////////////////////////////////////////

    PhiversMC #(
        .N_PE_X       (N_PE_X      ),
        .N_PE_Y       (N_PE_Y      ),
        .TASKS_PER_PE (TASKS_PER_PE),
        .IMEM_PAGE_SZ (IMEM_PAGE_SZ),
        .DMEM_PAGE_SZ (DMEM_PAGE_SZ),
        .ADDR_MA_INJ  (ADDR_MA_INJ ),
        .PORT_MA_INJ  (PORT_MA_INJ ),
        .ADDR_APP_INJ (ADDR_APP_INJ),
        .PORT_APP_INJ (PORT_APP_INJ),
        .DEBUG        (1           ),
        .Environment  (ASIC        )
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
        .imem_addr_o      (imem_addr      ),
        .imem_data_i      (imem_data      ),
        .dmem_en_o        (dmem_en        ),
        .dmem_we_o        (dmem_we        ),
        .dmem_addr_o      (dmem_addr      ),
        .dmem_data_i      (dmem_data_read ),
        .dmem_data_o      (dmem_data_write),
        .idma_en_o        (idma_en        ),
        .ddma_en_o        (ddma_en        ),
        .dma_we_o         (dma_we         ),
        .dma_addr_o       (dma_addr       ),
        .idma_data_i      (idma_data      ),
        .ddma_data_i      (ddma_data      ),
        .dma_data_o       (dma_data       )
    );

//////////////////////////////////////////////////////////////////////////////
// Memory
//////////////////////////////////////////////////////////////////////////////

    localparam IMEM_SZ = IMEM_PAGE_SZ * (TASKS_PER_PE + 1);
    localparam KERNEL_TEXT = "ikernel.bin";

    localparam DMEM_SZ = DMEM_PAGE_SZ * (TASKS_PER_PE + 1);
    localparam KERNEL_DATA = "dkernel.bin";

    generate
        for (genvar x = 0; x < N_PE_X; x++) begin : gen_pe_x
            for (genvar y = 0; y < N_PE_Y; y++) begin : gen_pe_y
                RAM_mem #(
                    .MEM_WIDTH  (IMEM_SZ                                 ),
                    .BIN_FILE   (KERNEL_TEXT                             ),
                    .DEBUG      (1                                       ),
                    .DEBUG_FILE ($sformatf("./debug/ram/%0dx%0d_I", x, y))
                ) 
                I_MEM (
                    .clk        (clk                                     ),

                    .enA_i      (1'b1                                    ), 
                    .weA_i      (4'h0                                    ), 
                    .addrA_i    (imem_addr[x][y][($clog2(IMEM_SZ) - 1):0]), 
                    .dataA_i    (32'h0                                   ), 
                    .dataA_o    (imem_data[x][y]                         ),

                    .enB_i      (idma_en[x][y]                           ), 
                    .weB_i      (dma_we[x][y]                            ), 
                    .addrB_i    (dma_addr[x][y][($clog2(IMEM_SZ) - 1):0] ), 
                    .dataB_i    (dma_data[x][y]                          ), 
                    .dataB_o    (idma_data[x][y]                         )
                );

                RAM_mem #(
                    .MEM_WIDTH  (DMEM_SZ                                 ),
                    .BIN_FILE   (KERNEL_DATA                             ),
                    .DEBUG      (1                                       ),
                    .DEBUG_FILE ($sformatf("./debug/ram/%0dx%0d_D", x, y))
                ) 
                D_MEM (
                    .clk        (clk                                     ), 

                    .enA_i      (dmem_en[x][y]                           ), 
                    .weA_i      (dmem_we[x][y]                           ), 
                    .addrA_i    (dmem_addr[x][y][($clog2(DMEM_SZ) - 1):0]), 
                    .dataA_i    (dmem_data_write[x][y]                   ), 
                    .dataA_o    (dmem_data_read[x][y]                    ),

                    .enB_i      (ddma_en[x][y]                           ), 
                    .weB_i      (dma_we[x][y]                            ), 
                    .addrB_i    (dma_addr[x][y][($clog2(DMEM_SZ) - 1):0] ), 
                    .dataB_i    (dma_data[x][y]                          ), 
                    .dataB_o    (ddma_data[x][y]                         )
                );
            end
        end
    endgenerate

//////////////////////////////////////////////////////////////////////////////
// INJECTORS
//////////////////////////////////////////////////////////////////////////////

    TaskParser #(
        .FLIT_SIZE    (32            ),
        .INJECT_MAPPER(1             ),
        .START_FILE   ("ma_start.txt"),
        .APP_PATH     ("management"  )
    )
    ma_src (
        .clk_i            (clk           ),
        .rst_ni           (rst_n         ),
        .tx_o             (ma_src_rx     ),
        .credit_i         (ma_src_credit ),
        .data_o           (ma_src_data   ),
        .mapper_address_o (mapper_address)
    );

    TaskParser #(
        .FLIT_SIZE    (32             ),
        .INJECT_MAPPER(0              ),
        .START_FILE   ("app_start.txt"),
        .APP_PATH     ("applications" )
    )
    app_src (
        .clk_i            (clk           ),
        .rst_ni           (rst_n         ),
        .eoa_o            (eoa           ),
        .tx_o             (app_src_rx    ),
        .credit_i         (app_src_credit),
        .data_o           (app_src_data  )
    );

endmodule
