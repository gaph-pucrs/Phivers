`include "../RS5/rtl/RS5_pkg.sv"
`include "../Hermes/rtl/HermesPkg.sv"
`include "../BrLite/rtl/BrLitePkg.sv"
`include "../DMNI/rtl/DMNIPkg.sv"

module PhiversPE
    import RS5_pkg::*;
    import HermesPkg::*;
    import BrLitePkg::*;
    import DMNIPkg::*;
#(
    parameter logic [15:0]  ADDRESS       = 16'b0,
    parameter               N_PE_X        = 2,
    parameter               N_PE_Y        = 2,
    parameter               TASKS_PER_PE  = 1,
    parameter               PAGE_SZ       = 32768,
    parameter environment_e Environment   = ASIC,
    parameter bit           UART_DEBUG    = 1,
    parameter bit           SCHED_DEBUG   = 1,
    parameter bit           PIPE_DEBUG    = 1,
    parameter bit           TRAFFIC_DEBUG = 1,
    parameter bit           DMNI_DEBUG    = 0,
    parameter bit           SAFE_DEBUG    = 1,
    parameter bit           VEnable       = 0,
    parameter int           VLEN          = 64
)
(
    input  logic                        clk_i,
    input  logic                        rst_ni,

    /* OBI instruction interface: read-only */
    output logic                        instr_req_o,
    input  logic                        instr_gnt_i,
    output logic     [31:0]             instr_addr_o,
    input  logic                        instr_rvalid_i,
    input  logic     [31:0]             instr_rdata_i,

    /* OBI memory interface: load/store and DMA, atomics already resolved */
    output logic                        mem_req_o,
    input  logic                        mem_gnt_i,
    output logic     [31:0]             mem_addr_o,
    output logic                        mem_we_o,
    output logic     [3:0]              mem_be_o,
    output logic     [31:0]             mem_wdata_o,
    input  logic                        mem_rvalid_i,
    input  logic     [31:0]             mem_rdata_i,

    /* NoC input interface */
    output logic                        release_peripheral_o,
    input  logic                        noc_rx_i              [(HERMES_NPORT - 2):0],
    input  logic                        noc_eop_i             [(HERMES_NPORT - 2):0],
    output logic                        noc_credit_o          [(HERMES_NPORT - 2):0],
    input  logic     [31:0]             noc_data_i            [(HERMES_NPORT - 2):0],

    /* NoC output interface */
    output logic                        noc_tx_o              [(HERMES_NPORT - 2):0],
    output logic                        noc_eop_o             [(HERMES_NPORT - 2):0],
    input  logic                        noc_credit_i          [(HERMES_NPORT - 2):0],
    output logic     [31:0]             noc_data_o            [(HERMES_NPORT - 2):0],

    /* BrLite input interface */
    input  logic     [(BR_NPORT - 2):0] brlite_req_i,
    output logic     [(BR_NPORT - 2):0] brlite_ack_o,
    input  br_data_t [(BR_NPORT - 2):0] brlite_flit_i,

    /* BrLite output interface */
    output logic     [(BR_NPORT - 2):0] brlite_req_o,
    input  logic     [(BR_NPORT - 2):0] brlite_ack_i,
    output br_data_t [(BR_NPORT - 2):0] brlite_flit_o
);

////////////////////////////////////////////////////////////////////////////////
// Core
////////////////////////////////////////////////////////////////////////////////

    logic        mei;
    logic        mti;

    logic        irq_ack;
    logic [63:0] mtime;

    logic        data_req;
    logic        data_gnt;
    logic [31:0] data_addr;
    logic        data_we;
    logic [3:0]  data_be;
    logic [31:0] data_wdata;
    logic [5:0]  data_atop;
    logic        data_rvalid;
    logic [31:0] data_rdata;
    logic        data_exokay;

    RS5 #(
        .Environment     (Environment),
        .MULEXT          (MUL_M      ),
        .AMOEXT          (AMO_A      ),
        .START_ADDR      ('0         ),
        .COMPRESSED      (1'b1       ),
        .VEnable         (VEnable    ),
        .VLEN            (VLEN       ),
        .XOSVMEnable     (1'b1       ),
        .ZKNEEnable      (1'b0       ),
        .ZICONDEnable    (1'b1       ),
        .ZCBEnable       (1'b1       ),
        .HPMCOUNTEREnable(1'b0       ),
        .BRANCHPRED      (1'b1       ),
        .FORWARDING      (1'b1       )
    )
    processor (
        .clk            (clk_i         ),
        .reset_n        (rst_ni        ),
        .sys_reset_i    (1'b0          ),
        .tip_i          (mti           ),
        .eip_i          (mei           ),
        .interrupt_ack_o(irq_ack       ),
        .mtime_i        (mtime         ),
        .instr_req_o    (instr_req_o   ),
        .instr_gnt_i    (instr_gnt_i   ),
        .instr_addr_o   (instr_addr_o  ),
        .instr_rvalid_i (instr_rvalid_i),
        .instr_rdata_i  (instr_rdata_i ),
        .data_req_o     (data_req      ),
        .data_gnt_i     (data_gnt      ),
        .data_addr_o    (data_addr     ),
        .data_we_o      (data_we       ),
        .data_be_o      (data_be       ),
        .data_wdata_o   (data_wdata    ),
        .data_atop_o    (data_atop     ),
        .data_rvalid_i  (data_rvalid   ),
        .data_rdata_i   (data_rdata    ),
        .data_exokay_i  (data_exokay   )
    );

////////////////////////////////////////////////////////////////////////////////
// PLIC
////////////////////////////////////////////////////////////////////////////////

    logic        dmni_irq;

    /* Currently there is no need for acking peripherals through PLIC */
    /* verilator lint_off UNUSEDSIGNAL */
    logic        plic_ack;
    /* verilator lint_on UNUSEDSIGNAL */

    logic        plic_en;
    logic        plic_rvalid;
    logic [31:0] plic_data_read;

    /* OBI subordinates that never stall: the data bus grants for them */
    /* verilator lint_off UNUSEDSIGNAL */
    logic        plic_gnt;
    logic        rtc_gnt;
    /* verilator lint_on UNUSEDSIGNAL */

    plic #(
        .i_cnt(1)
    )
    plic_m (
        .clk     (clk_i          ),
        .reset_n (rst_ni         ),
        .req_i   (plic_en        ),
        .gnt_o   (plic_gnt       ),
        .addr_i  (data_addr[23:0]),
        .we_i    (data_we        ),
        .be_i    (data_be        ),
        .wdata_i (data_wdata     ),
        .rvalid_o(plic_rvalid    ),
        .rdata_o (plic_data_read ),
        .irq_i   (dmni_irq       ),
        .iack_i  (irq_ack        ),
        .iack_o  (plic_ack       ),
        .irq_o   (mei            )
    );

////////////////////////////////////////////////////////////////////////////////
// RTC
////////////////////////////////////////////////////////////////////////////////

    logic        rtc_en;
    logic        rtc_rvalid;
    logic [31:0] rtc_data_read;

    rtc
    rtc_m (
        .clk     (clk_i         ),
        .reset_n (rst_ni        ),
        .req_i   (rtc_en        ),
        .gnt_o   (rtc_gnt       ),
        .addr_i  (data_addr[3:0]),
        .we_i    (data_we       ),
        .be_i    (data_be       ),
        .wdata_i (data_wdata    ),
        .rvalid_o(rtc_rvalid    ),
        .rdata_o (rtc_data_read ),
        .mti_o   (mti           ),
        .mtime_o (mtime         )
    );

////////////////////////////////////////////////////////////////////////////////
// NoC
////////////////////////////////////////////////////////////////////////////////

    logic        noc_rx         [(HERMES_NPORT - 1):0];
    logic        noc_eop_rcv    [(HERMES_NPORT - 1):0];
    logic        noc_credit_rcv [(HERMES_NPORT - 1):0];
    logic [31:0] noc_data_rcv   [(HERMES_NPORT - 1):0];

    assign noc_rx      [(HERMES_NPORT - 2):0] = noc_rx_i;
    assign noc_eop_rcv [(HERMES_NPORT - 2):0] = noc_eop_i;
    assign noc_data_rcv[(HERMES_NPORT - 2):0] = noc_data_i;
    assign noc_credit_o                       = noc_credit_rcv[(HERMES_NPORT - 2):0];

    logic        noc_tx         [(HERMES_NPORT - 1):0];
    logic        noc_eop_snd    [(HERMES_NPORT - 1):0];
    logic        noc_credit_snd [(HERMES_NPORT - 1):0];
    logic [31:0] noc_data_snd   [(HERMES_NPORT - 1):0];

    assign noc_tx_o                             = noc_tx      [(HERMES_NPORT - 2):0];
    assign noc_eop_o                            = noc_eop_snd [(HERMES_NPORT - 2):0];
    assign noc_data_o                           = noc_data_snd[(HERMES_NPORT - 2):0];
    assign noc_credit_snd[(HERMES_NPORT - 2):0] = noc_credit_i;

    HermesRouter #(
        .ADDRESS(ADDRESS),
        .BUFFER_SIZE(8),
        .FLIT_SIZE(32)
    )
    router (
        .clk_i    (clk_i         ),
        .rst_ni   (rst_ni        ),
        .rx_i     (noc_rx        ),
        .eop_i    (noc_eop_rcv   ),
        .credit_o (noc_credit_rcv),
        .data_i   (noc_data_rcv  ),
        .tx_o     (noc_tx        ),
        .eop_o    (noc_eop_snd   ),
        .credit_i (noc_credit_snd),
        .data_o   (noc_data_snd  )
    );

////////////////////////////////////////////////////////////////////////////////
// BrNoC
////////////////////////////////////////////////////////////////////////////////

    logic brlite_local_busy;

    logic     [(BR_NPORT - 1):0] brlite_req_rcv;
    logic     [(BR_NPORT - 1):0] brlite_ack_rcv;
    br_data_t [(BR_NPORT - 1):0] brlite_flit_rcv;

    assign brlite_req_rcv [(BR_NPORT - 2):0] = brlite_req_i;
    assign brlite_flit_rcv[(BR_NPORT - 2):0] = brlite_flit_i;
    assign brlite_ack_o                      = brlite_ack_rcv[(BR_NPORT - 2):0];

    logic     [(BR_NPORT - 1):0] brlite_req_snd;
    logic     [(BR_NPORT - 1):0] brlite_ack_snd;
    br_data_t [(BR_NPORT - 1):0] brlite_flit_snd;

    assign brlite_req_o                     = brlite_req_snd [(BR_NPORT - 2):0];
    assign brlite_flit_o                    = brlite_flit_snd[(BR_NPORT - 2):0];
    assign brlite_ack_snd[(BR_NPORT - 2):0] = brlite_ack_i;

    localparam logic [15:0] seq_addr = ADDRESS[7:0] * N_PE_X + {8'h00, ADDRESS[15:8]};
    BrLiteRouter #(
        .SEQ_ADDRESS (seq_addr),
        .CAM_SIZE    (8       ),
        .CLEAR_TICKS (150     )
    )
    br_router (
        .clk_i        (clk_i            ),
        .rst_ni       (rst_ni           ),
        .local_busy_o (brlite_local_busy),
        .flit_i       (brlite_flit_rcv  ),
        .req_i        (brlite_req_rcv   ),
        .ack_o        (brlite_ack_rcv   ),
        .flit_o       (brlite_flit_snd  ),
        .req_o        (brlite_req_snd   ),
        .ack_i        (brlite_ack_snd   )
    );

////////////////////////////////////////////////////////////////////////////////
// DMNI
////////////////////////////////////////////////////////////////////////////////

    logic        ni_en;
    logic        ni_rvalid;
    logic [31:0] ni_data_read;

    /* Never stalls: the data bus grants for it */
    /* verilator lint_off UNUSEDSIGNAL */
    logic        ni_gnt;
    /* verilator lint_on UNUSEDSIGNAL */

    logic        dma_req;
    logic        dma_gnt;
    logic [31:0] dma_addr;
    logic        dma_we;
    logic [3:0]  dma_be;
    logic [31:0] dma_wdata;
    logic        dma_rvalid;

    logic        brlite_req;
    logic        brlite_ack;
    br_payload_t brlite_flit;

    assign brlite_req = brlite_req_snd[(BR_NPORT - 1)];
    assign brlite_flit.payload    = brlite_flit_snd[(BR_NPORT - 1)].payload;
    assign brlite_flit.seq_source = brlite_flit_snd[(BR_NPORT - 1)].seq_source;
    assign brlite_flit.ksvc       = brlite_flit_snd[(BR_NPORT - 1)].ksvc;

    assign brlite_ack_snd[(BR_NPORT - 1)] = brlite_ack;

    logic [4:0] brlite_id;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            brlite_id <= '0;
        else if (brlite_ack_rcv[(BR_NPORT - 1)])
            brlite_id <= brlite_id + 1'b1;
    end

    /* We ignore seq_source here */
    /* verilator lint_off UNUSEDSIGNAL */
    br_payload_t brlite_flit_ni;
    /* verilator lint_on UNUSEDSIGNAL */

    assign brlite_flit_rcv[(BR_NPORT - 1)].payload    = brlite_flit_ni.payload;
    assign brlite_flit_rcv[(BR_NPORT - 1)].seq_source = seq_addr;
    assign brlite_flit_rcv[(BR_NPORT - 1)].ksvc       = brlite_flit_ni.ksvc;
    assign brlite_flit_rcv[(BR_NPORT - 1)].id         = brlite_id;
    assign brlite_flit_rcv[(BR_NPORT - 1)].clear      = 1'b0;

    DMNI #(
        .HERMES_FLIT_SIZE   (32          ),
        .HERMES_BUFFER_SIZE (8           ),
        .BR_BUFFER_SIZE     (4           ),
        .N_PE_X             (N_PE_X      ),
        .N_PE_Y             (N_PE_Y      ),
        .TASKS_PER_PE       (TASKS_PER_PE),
        .PAGE_SZ            (PAGE_SZ     ),
        .ADDRESS            (ADDRESS     )
    )
    dmni (
        .clk_i                (clk_i                                  ),
        .rst_ni               (rst_ni                                 ),
        .tick_counter_i       (mtime[31:0]                            ),
        .irq_o                (dmni_irq                               ),
        .cfg_req_i            (ni_en                                  ),
        .cfg_gnt_o            (ni_gnt                                 ),
        .cfg_addr_i           (data_addr[7:0]                         ),
        .cfg_we_i             (data_we                                ),
        .cfg_be_i             (data_be                                ),
        .cfg_wdata_i          (data_wdata                             ),
        .cfg_rvalid_o         (ni_rvalid                              ),
        .cfg_rdata_o          (ni_data_read                           ),
        .release_peripheral_o (release_peripheral_o                   ),
        .mem_req_o            (dma_req                                ),
        .mem_gnt_i            (dma_gnt                                ),
        .mem_addr_o           (dma_addr                               ),
        .mem_we_o             (dma_we                                 ),
        .mem_be_o             (dma_be                                 ),
        .mem_wdata_o          (dma_wdata                              ),
        .mem_rvalid_i         (dma_rvalid                             ),
        .mem_rdata_i          (amu_rdata                              ),
        .noc_rx_i             (noc_tx        [HERMES_NPORT - 1]       ),
        .noc_eop_i            (noc_eop_snd   [HERMES_NPORT - 1]       ),
        .noc_credit_o         (noc_credit_snd[HERMES_NPORT - 1]       ),
        .noc_data_i           (noc_data_snd  [HERMES_NPORT - 1]       ),
        .noc_tx_o             (noc_rx        [HERMES_NPORT - 1]       ),
        .noc_eop_o            (noc_eop_rcv   [HERMES_NPORT - 1]       ),
        .noc_credit_i         (noc_credit_rcv[HERMES_NPORT - 1]       ),
        .noc_data_o           (noc_data_rcv  [HERMES_NPORT - 1]       ),
        .br_req_i             (brlite_req                             ),
        .br_ack_o             (brlite_ack                             ),
        .br_data_i            (brlite_flit                            ),
        .br_local_busy_i      (brlite_local_busy                      ),
        .br_req_o             (brlite_req_rcv[BR_NPORT - 1]           ),
        .br_ack_i             (brlite_ack_rcv[BR_NPORT - 1]           ),
        .br_data_o            (brlite_flit_ni                         )
    );

////////////////////////////////////////////////////////////////////////////////
// Data bus
////////////////////////////////////////////////////////////////////////////////

    /**
     * Memory map:
     * [0x00000000, 0x80000000[ -> memory
     * [0x80000000, 0x90000000[ -> PLIC
     * [0x90000000, 0xA0000000[ -> NI
     * [0xA0000000, 0xB0000000[ -> RTC
     * [0xF0000000, 0xFFFFFFFF] -> DEBUG
     *
     * Peripherals are accessed in the grant cycle and answer in the next one.
     * The memory is shared by the CPU and the DMA, which only access memory.
     * Blocking receives spin on the NI registers, so they never lose the bus.
     */

    logic cpu_mem_req;
    logic periph_req;
    assign cpu_mem_req = data_req && (data_addr[31] == 1'b0);
    assign periph_req  = data_req && (data_addr[31] == 1'b1);

    /* CPU memory transactions granted and not answered yet */
    logic [1:0] cpu_mem_pending;

    /* OBI: a manager gets its responses in order, and a peripheral answers */
    /* faster than the memory, so it waits for the memory to answer first   */
    logic periph_gnt;
    assign periph_gnt = periph_req && (cpu_mem_pending == '0);

    assign plic_en = periph_gnt && (data_addr[31:28] == 4'b1000);
    assign ni_en   = periph_gnt && (data_addr[31:28] == 4'b1001);
    assign rtc_en  = periph_gnt && (data_addr[31:28] == 4'b1010);

    /* Every peripheral answers in the next cycle, Debug and unmapped addresses too */
    logic periph_gnt_r;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            periph_gnt_r <= 1'b0;
        else
            periph_gnt_r <= periph_gnt;
    end


    /* Requests reaching the atomic unit: the CPU (id 0) or the DMA (id 1) */
    logic        amu_req;
    logic        amu_gnt;
    logic [31:0] amu_addr;
    logic        amu_we;
    logic [3:0]  amu_be;
    logic [31:0] amu_wdata;
    logic [5:0]  amu_atop;
    logic        amu_rvalid;
    logic [31:0] amu_rdata;
    logic        amu_exokay;

    /**
     * Arbiter: the CPU first, but a request left waiting keeps the bus until
     * its gnt, as OBI forbids changing a request before it is granted.
     */
    logic held;
    logic held_dma;
    logic sel_dma;
    assign sel_dma = held ? held_dma : !cpu_mem_req;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            held <= 1'b0;
        else
            held <= amu_req && !amu_gnt;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            held_dma <= 1'b0;
        else
            held_dma <= sel_dma;
    end

    /* Responses come back in order: the owner of each one, oldest first */
    logic owner_room;
    logic rsp_dma;

    /* verilator lint_off UNUSEDSIGNAL */
    logic owner_tx;
    logic owner_almost_full;
    logic owner_almost_empty;
    logic [3:0] owner_count;
    /* verilator lint_on UNUSEDSIGNAL */

    logic sel_req;
    assign sel_req = sel_dma ? dma_req : cpu_mem_req;

    /* The owner FIFO only frees room while a request waits, so it stays stable */
    assign amu_req   = sel_req && owner_room;
    assign amu_addr  = sel_dma ? dma_addr  : data_addr;
    assign amu_we    = sel_dma ? dma_we    : data_we;
    assign amu_be    = sel_dma ? dma_be    : data_be;
    assign amu_wdata = sel_dma ? dma_wdata : data_wdata;
    assign amu_atop  = sel_dma ? '0        : data_atop;

    logic amu_accept;
    assign amu_accept = amu_req && amu_gnt;

    /* CPU (2 in flight) and DMA (4 in flight) */
    RingBuffer #(
        .DATA_SIZE              (1),
        .BUFFER_SIZE            (8),
        .FIRST_WORD_FALL_THROUGH(0),
        .ALMOST_FULL_THRESHOLD  (0),
        .ALMOST_EMPTY_THRESHOLD (0)
    )
    owner_buffer (
        .clk_i         (clk_i             ),
        .rst_ni        (rst_ni            ),
        .buf_rst_i     (1'b0              ),
        .rx_i          (amu_accept        ),
        .rx_ack_o      (owner_room        ),
        .data_i        (sel_dma           ),
        .tx_o          (owner_tx          ),
        .tx_ack_i      (amu_rvalid        ),
        .data_o        (rsp_dma           ),
        .count_o       (owner_count       ),
        .almost_full_o (owner_almost_full ),
        .almost_empty_o(owner_almost_empty)
    );

    AtomicALU #(
        .AMOEXT    (AMO_A),
        .BUS_WIDTH (32   ),
        .NUM_IDS   (2    )
    )
    amu (
        .clk      (clk_i       ),
        .reset_n  (rst_ni      ),
        .req_i    (amu_req     ),
        .gnt_o    (amu_gnt     ),
        .addr_i   (amu_addr    ),
        .we_i     (amu_we      ),
        .be_i     (amu_be      ),
        .wdata_i  (amu_wdata   ),
        .atop_i   (amu_atop    ),
        .aid_i    (sel_dma     ),
        .rvalid_o (amu_rvalid  ),
        .rdata_o  (amu_rdata   ),
        .exokay_o (amu_exokay  ),
        .req_o    (mem_req_o   ),
        .gnt_i    (mem_gnt_i   ),
        .addr_o   (mem_addr_o  ),
        .we_o     (mem_we_o    ),
        .be_o     (mem_be_o    ),
        .wdata_o  (mem_wdata_o ),
        .rvalid_i (mem_rvalid_i),
        .rdata_i  (mem_rdata_i )
    );

    logic cpu_mem_gnt;
    assign cpu_mem_gnt = !sel_dma && amu_gnt;

    logic cpu_mem_rvalid;
    assign cpu_mem_rvalid = amu_rvalid && !rsp_dma;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            cpu_mem_pending <= '0;
        else
            cpu_mem_pending <= cpu_mem_pending + 2'(cpu_mem_req && cpu_mem_gnt) - 2'(cpu_mem_rvalid);
    end

    assign dma_gnt    = sel_dma && amu_gnt;
    assign dma_rvalid = amu_rvalid && rsp_dma;

    assign data_gnt    = periph_gnt || cpu_mem_gnt;
    assign data_rvalid = periph_gnt_r || cpu_mem_rvalid;
    assign data_exokay = amu_exokay;

    always_comb begin
        if (rtc_rvalid)
            data_rdata = rtc_data_read;
        else if (plic_rvalid)
            data_rdata = plic_data_read;
        else if (ni_rvalid)
            data_rdata = ni_data_read;
        else
            data_rdata = amu_rdata;
    end

////////////////////////////////////////////////////////////////////////////////
// DEBUG connections
////////////////////////////////////////////////////////////////////////////////

    logic dbg_en;
    logic dbg_we;

    assign dbg_en = periph_gnt && (data_addr[31:28] == 4'b1111);
    assign dbg_we = data_we;
    
    Debug #(
        .ADDRESS         (ADDRESS                        ),
        .SEQ_ADDR        (seq_addr                       ),
        .UART_DEBUG      (UART_DEBUG                     ),
        .SCHED_DEBUG     (SCHED_DEBUG                    ),
        .PIPE_DEBUG      (PIPE_DEBUG                     ),
        .TRAFFIC_DEBUG   (TRAFFIC_DEBUG                  ),
        .SAFE_DEBUG      (SAFE_DEBUG                     ),
        .DBG_SCHED_FILE  ("./debug/scheduling_report.txt"),
        .DBG_TRAFFIC_FILE("./debug/traffic_router.txt"   )
    )
    dbg (
        .clk_i      (clk_i          ),
        .rst_ni     (rst_ni         ),
        .en_i       (dbg_en         ),
        .we_i       (dbg_we         ),
        .addr_i     (data_addr[23:0]),
        .data_i     (data_wdata     ),
        .tick_cntr_i(mtime          )
    );

    if (TRAFFIC_DEBUG) begin : gen_traffic_dbg
        for (genvar p = 0; p < HERMES_NPORT; p++) begin : gen_traffic_router
            TrafficRouter #(
                .FLIT_SIZE(32                          ),
                .ADDRESS  (ADDRESS                     ),
                .PORT     (hermes_port_t'(p)           ),
                .FILE_NAME("./debug/traffic_router.txt")
            )
            traffic_router (
                .clk_i      (clk_i            ),
                .rst_ni     (rst_ni           ),
                .rx_i       (noc_rx[p]        ),
                .eop_i      (noc_eop_rcv[p]   ),
                .credit_i   (noc_credit_rcv[p]),
                .data_i     (noc_data_rcv[p]  ),
                .tick_cntr_i(mtime            )
            );

            TrafficBroadcast #(
                .ADDRESS  (ADDRESS                     ),
                .PORT     (br_port_t'(p)               ),
                .FILE_NAME("./debug/traffic_router.txt")
            )
            traffic_broadcast (
                .clk_i      (clk_i             ),
                .rst_ni     (rst_ni            ),
                .rx_i       (brlite_req_rcv[p] ),
                .ack_rx_i   (brlite_ack_rcv[p] ),
                .data_i     (brlite_flit_rcv[p]),
                .tick_cntr_i(mtime             )
            );
        end
    end

    if (DMNI_DEBUG) begin : gen_dmni_dbg
        DMNILog #(
            .FLIT_SIZE(32            ),
            .ADDRESS  (ADDRESS       ),
            .LOG_PATH ("./debug/dmni")
        )
        dmni_log (
            .clk_i      (         clk_i                  ),
            .rst_ni     (        rst_ni                  ),
            .tx_i       (        noc_tx[HERMES_NPORT - 1]),
            .eop_i      (   noc_eop_snd[HERMES_NPORT - 1]),
            .credit_i   (noc_credit_snd[HERMES_NPORT - 1]),
            .data_i     (  noc_data_snd[HERMES_NPORT - 1]),
            .tick_cntr_i(         mtime                  )
        );
    end

endmodule
