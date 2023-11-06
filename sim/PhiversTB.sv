module PhiversTB
    import RS5_pkg::*;
(
);

    logic clk;
    logic rst_n;

    logic [15:0] mapper_address;
    
    logic        ma_src_rx;
    logic        ma_src_credit;
    logic [31:0] ma_src_data;
    
    logic        app_src_rx;
    logic        app_src_credit;
    logic [31:0] app_src_data;

    logic [23:0] imem_addr       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] imem_data       [(N_PE_X - 1):0][(N_PE_Y - 1):0];

    logic [3:0]  dmem_we         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [23:0] dmem_addr       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] dmem_data_read  [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] dmem_data_write [(N_PE_X - 1):0][(N_PE_Y - 1):0];

    logic        idma_en         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        ddma_en         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [3:0]  dma_we          [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    logic [23:0] dma_addr        [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] idma_data       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] ddma_data       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] dma_data        [(N_PE_X - 1):0][(N_PE_Y - 1):0];


//////////////////////////////////////////////////////////////////////////////
// Many Core
//////////////////////////////////////////////////////////////////////////////

    PhiversMC #(
        .N_PE_X       (/* @todo */),
        .N_PE_Y       (/* @todo */),
        .TASKS_PER_PE (/* @todo */),
        .ADDR_MA_INJ  (/* @todo */),
        .PORT_MA_INJ  (/* @todo */),
        .ADDR_APP_INJ (/* @todo */),
        .PORT_APP_INJ (/* @todo */),
        .Environment  (ASIC)
    )
    mc (
        .clk              (clk            ),
        .rst_n            (rst_n          ),
        .mapper_address_i (mapper_address ),
        .ma_src_rx_i      (ma_src_rx      ),
        .ma_src_credit_o  (ma_src_credit  ),
        .ma_src_data_i    (ma_src_data    ),
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
// Instruction Memory
//////////////////////////////////////////////////////////////////////////////

    generate
        for (genvar x = 0; x < N_PE_X; x++) begin
            for (genvar y = 0; y < N_PE_Y; y++) begin
                RAM_mem #(
                    .MEM_WIDTH (/* @todo */),
                    .BIN_FILE  (/* @todo */)
                ) 
                I_MEM (
                    .clk        (clk            ),

                    .enA_i      (1'b1           ), 
                    .weA_i      (4'h0           ), 
                    .addrA_i    (imem_addr[x][y]), 
                    .dataA_i    (32'h0          ), 
                    .dataA_o    (imem_data[x][y]),

                    .enB_i      (idma_en[x][y]  ), 
                    .weB_i      (dma_we[x][y]   ), 
                    .addrB_i    (dma_addr[x][y] ), 
                    .dataB_i    (dma_data[x][y] ), 
                    .dataB_o    (idma_data[x][y])
                );

                RAM_mem #(
                    .MEM_WIDTH (/* @todo */),
                    .BIN_FILE  (/* @todo */)
                ) 
                D_MEM (
                    .clk        (clk                  ), 

                    .enA_i      (dmem_en[x][y]        ), 
                    .weA_i      (dmem_we[x][y]        ), 
                    .addrA_i    (dmem_addr[x][y]      ), 
                    .dataA_i    (dmem_data_write[x][y]), 
                    .dataA_o    (dmem_data_read[x][y] ),

                    .enB_i      (ddma_en[x][y]        ), 
                    .weB_i      (dma_we[x][y]         ), 
                    .addrB_i    (dma_addr[x][y]       ), 
                    .dataB_i    (dma_data[x][y]       ), 
                    .dataB_o    (ddma_data[x][y]      )
                );

            end
        end
    endgenerate

//////////////////////////////////////////////////////////////////////////////
// INJECTOR
//////////////////////////////////////////////////////////////////////////////

    MAParser #(
        .PATH      (/* @todo */),
        .FLIT_SIZE (32         )
    )
    ma_src (
        .clk_i            (clk           ),
        .rst_ni           (rst_n         ),
        .tx_o             (ma_src_rx     ),
        .credit_i         (ma_src_credit ),
        .data_o           (ma_src_data   ),
        .mapper_address_o (mapper_address)
    );

    AppParser #(
        .PATH      (/* @todo */),
        .SIM_FREQ  (/* @todo */),
        .FLIT_SIZE (32         )
    )
    app_src (
        .clk_i            (clk           ),
        .rst_ni           (rst_n         ),
        .eoa_o            (/* @todo */   ),
        .tx_o             (app_src_rx    ),
        .credit_i         (app_src_credit),
        .data_o           (app_src_data  ),
    );

endmodule
