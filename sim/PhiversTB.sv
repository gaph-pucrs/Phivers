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

    /* Bit 31 selects the peripherals and never reaches the memory */
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] instr_addr      [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] mem_addr        [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    /* verilator lint_on UNUSEDSIGNAL */

    logic        instr_req       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        instr_gnt       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        instr_rvalid    [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] instr_rdata     [(N_PE_X - 1):0][(N_PE_Y - 1):0];

    logic        mem_req         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        mem_gnt         [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        mem_we          [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [3:0]  mem_be          [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] mem_wdata       [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        mem_rvalid      [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic [31:0] mem_rdata       [(N_PE_X - 1):0][(N_PE_Y - 1):0];

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
        .instr_req_o      (instr_req      ),
        .instr_gnt_i      (instr_gnt      ),
        .instr_addr_o     (instr_addr     ),
        .instr_rvalid_i   (instr_rvalid   ),
        .instr_rdata_i    (instr_rdata    ),
        .mem_req_o        (mem_req        ),
        .mem_gnt_i        (mem_gnt        ),
        .mem_addr_o       (mem_addr       ),
        .mem_we_o         (mem_we         ),
        .mem_be_o         (mem_be         ),
        .mem_wdata_o      (mem_wdata      ),
        .mem_rvalid_i     (mem_rvalid     ),
        .mem_rdata_i      (mem_rdata      )
    );

    /**
     * Debug monitors, bound into every PhiversPE. Their switches are macros
     * from PhiversPkg, not parameters: Verilator applies a bind even inside a
     * false generate if. Ports and parameters resolve inside each PE.
     */

    /* Always bound: the kernel also ends the simulation through it */
    bind PhiversPE Debug #(
        .ADDRESS         (ADDRESS                        ),
        .SEQ_ADDR        (seq_addr                       ),
        .DBG_SCHED_FILE  ("./debug/scheduling_report.txt"),
        .DBG_TRAFFIC_FILE("./debug/traffic_router.txt"   )
    ) dbg (
        .clk_i      (clk_i     ),
        .rst_ni     (rst_ni    ),
        .req_i      (data_req  ),
        .gnt_i      (data_gnt  ),
        .addr_i     (data_addr ),
        .we_i       (data_we   ),
        .wdata_i    (data_wdata),
        .tick_cntr_i(mtime     )
    );

`ifdef TRAFFIC_DEBUG
    bind PhiversPE TrafficDebug #(
        .ADDRESS(ADDRESS)
    ) traffic_dbg (
        .clk_i            (clk_i          ),
        .rst_ni           (rst_ni         ),
        .noc_rx_i         (noc_rx         ),
        .noc_eop_rcv_i    (noc_eop_rcv    ),
        .noc_credit_rcv_i (noc_credit_rcv ),
        .noc_data_rcv_i   (noc_data_rcv   ),
        .brlite_req_rcv_i (brlite_req_rcv ),
        .brlite_ack_rcv_i (brlite_ack_rcv ),
        .brlite_flit_rcv_i(brlite_flit_rcv),
        .tick_cntr_i      (mtime          )
    );
`endif

`ifdef DMNI_DEBUG
    /* The local port of the router is the DMNI input */
    bind PhiversPE DMNILog #(
        .FLIT_SIZE(32            ),
        .ADDRESS  (ADDRESS       ),
        .LOG_PATH ("./debug/dmni")
    ) dmni_log (
        .clk_i      (clk_i                           ),
        .rst_ni     (rst_ni                          ),
        .tx_i       (noc_tx        [HERMES_NPORT - 1]),
        .eop_i      (noc_eop_snd   [HERMES_NPORT - 1]),
        .credit_i   (noc_credit_snd[HERMES_NPORT - 1]),
        .data_i     (noc_data_snd  [HERMES_NPORT - 1]),
        .tick_cntr_i(mtime                           )
    );
`endif

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

    localparam longint unsigned MEM_SZ = longint'(PAGE_SZ) * (TASKS_PER_PE + 1);
    localparam KERNEL = "../MAestro/kernel.bin";

    generate
        for (genvar x = 0; x < N_PE_X; x++) begin : gen_pe_x
            for (genvar y = 0; y < N_PE_Y; y++) begin : gen_pe_y
                /* The RAM always grants, is accessed with the request and answers in the next cycle */
                assign instr_gnt[x][y] = 1'b1;
                assign mem_gnt  [x][y] = 1'b1;

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        instr_rvalid[x][y] <= 1'b0;
                    else
                        instr_rvalid[x][y] <= instr_req[x][y];
                end

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        mem_rvalid[x][y] <= 1'b0;
                    else
                        mem_rvalid[x][y] <= mem_req[x][y];
                end

                logic [3:0] ram_we;
                assign ram_we = mem_we[x][y] ? mem_be[x][y] : 4'h0;

                /* Port A: instruction fetch. Port B: load/store and DMA. */
                RamArray #(
                    .MEM_WIDTH  (MEM_SZ                                ),
                    .BIN_FILE   (KERNEL                                )
                )
                MEM (
                    .clk        (clk                                   ),
                    .enA_i      (instr_req [x][y]                      ),
                    .weA_i      (4'h0                                  ),
                    .addrA_i    (instr_addr[x][y][($clog2(MEM_SZ) - 1):0]),
                    .dataA_i    (32'h0                                 ),
                    .dataA_o    (instr_rdata[x][y]                     ),
                    .enB_i      (mem_req   [x][y]                      ),
                    .weB_i      (ram_we                                ),
                    .addrB_i    (mem_addr  [x][y][($clog2(MEM_SZ) - 1):0]),
                    .dataB_i    (mem_wdata [x][y]                      ),
                    .dataB_o    (mem_rdata [x][y]                      )
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
                        .enA_i   (instr_req [x][y]      ),
                        .addrA_i (instr_addr[x][y][30:0]),
                        .enB_i   (mem_req   [x][y]      ),
                        .addrB_i (mem_addr  [x][y][30:0])
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
