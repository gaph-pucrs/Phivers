module PhiversPE
    import RS5_pkg::*;
    import HermesPkg::*;
    import BrLitePkg::*;
    import DMNIPkg::*;
#(
    parameter logic [15:0]  ADDRESS      = 0,
    parameter logic [15:0]  SEQ_ADDRESS  = 0,
    parameter               N_PE         = 16,
    parameter               TASKS_PER_PE = 4,
    parameter environment_e Environment  = ASIC
)
(
    input  logic clk_i,
    input  logic rst_ni,

    /* Instruction memory interface: read-only */
    output logic [31:0] imem_addr_o,
    input  logic [31:0] imem_data_i,

    /* Data memory interface: read/write */
    output logic        dmem_en_o,
    output logic [3:0]  dmem_we_o,
    output logic [31:0] dmem_addr_o,
    input  logic [31:0] dmem_data_i,
    output logic [31:0] dmem_data_o,

    /* DMA memory interface: read/write on instruction/data */
    output logic        idma_en_o,
    output logic        ddma_en_o
    output logic [3:0]  dma_we_o,
    output logic [31:0] dma_addr_o,
    input  logic [31:0] idma_data_i,
    input  logic [31:0] ddma_data_i,
    output logic [31:0] dma_data_o,

    /* NoC input interface */
    input  logic        noc_rx_i     [(NPORT - 2):0],
    output logic        noc_credit_o [(NPORT - 2):0],
    input  logic [31:0] noc_data_i   [(NPORT - 2):0],

    /* NoC output interface */
    output logic        noc_tx_i     [(NPORT - 2):0],
    input  logic        noc_credit_i [(NPORT - 2):0],
    output logic [31:0] noc_data_o   [(NPORT - 2):0],

    /* BrLite input interface */
    input  logic        brlite_req_i [(NPORT - 2):0],
    output logic        brlite_ack_o [(NPORT - 2):0],
    input  br_data_t    brlite_flit_i[(NPORT - 2):0],

    /* BrLite output interface */
    output logic        brlite_req_o [(NPORT - 2):0],
    input  logic        brlite_ack_i [(NPORT - 2):0],
    output br_data_t    brlite_flit_o[(NPORT - 2):0]
);

////////////////////////////////////////////////////////////////////////////////
// Core
////////////////////////////////////////////////////////////////////////////////

    logic rst;

    assign rst = ~rst_ni;

    logic        mei;
    logic        mti;
    logic [31:0] irq;

    assign irq = {20'b0, mei, 3'b0, mti, 7'b0};

    logic        cpu_en;
    logic [3:0]  cpu_we;
    logic [31:0] cpu_addr;
    logic [31:0] cpu_data_write;
    logic [31:0] cpu_data_read;

    assign dmem_we_o   = cpu_we;
    assign dmem_addr_o = cpu_addr;
    assign dmem_data_o = cpu_data_write;

    RS5 #(
        .Environment(Environment),
        .RV32(RV32)
        .XOSVMEnable(1),
        .ZIHPMEnable(1)
    )
    processor (
        .clk                    (clk_i         ),
        .reset                  (rst           ),
        .stall                  (1'b0          ),
        .instruction_i          (imem_data_i   ),
        .mem_data_i             (dmem_data_read),
        .mtime_i                (mtime         ),
        .irq_i                  (irq           ),
        .instruction_address_o  (imem_addr_o   ),
        .mem_operation_enable_o (cpu_en        ),
        .mem_write_enable_o     (cpu_we        ),
        .mem_address_o          (cpu_addr      ),
        .mem_data_o             (cpu_data_write),
        .interrupt_ack_o        (irq_ack       )
    );

////////////////////////////////////////////////////////////////////////////////
// PLIC
////////////////////////////////////////////////////////////////////////////////

    logic        plic_en;
    logic [31:0] plic_data_read;

    plic #(
        .i_cnt(/* @todo */),
    )
    plic_m (
        .clk    (clk_i         ),
        .reset  (rst           ),
        .en_i   (plic_en       ),
        .we_i   (cpu_we        ),
        .addr_i (cpu_addr      ),
        .data_i (cpu_data_write),
        .data_o (plic_data_read),
        .irq_i  (/* @todo */   ),
        .iack_i (irq_ack       ),
        .iack_o (/* @todo */   ),
        .irq_o  (mei           )
    );

////////////////////////////////////////////////////////////////////////////////
// RTC
////////////////////////////////////////////////////////////////////////////////

    logic        rtc_en;
    logic [31:0] rtc_data_read;
    logic [63:0] mtime;

    rtc 
    rtc_m (
        .clk     (clk_i         ),
        .reset   (rst           ),
        .en_i    (rtc_en        ),
        .addr_i  (cpu_addr      ),
        .we_i    (cpu_we        ),
        .data_i  (cpu_data_write),
        .data_o  (rtc_data_read ),
        .mti_o   (mti           ),
        .mtime_o (mtime         ),
    );

////////////////////////////////////////////////////////////////////////////////
// NoC
////////////////////////////////////////////////////////////////////////////////

    logic        noc_rx         [(NPORT - 1):0];
    logic        noc_credit_rcv [(NPORT - 1):0];
    logic [31:0] noc_data_rcv   [(NPORT - 1):0];

    assign noc_rx[(NPORT - 2):0]       = noc_rx_i;
    assign noc_credit_o                = noc_credit_rcv[(NPORT - 2):0];
    assign noc_data_rcv[(NPORT - 2):0] = noc_data_i;

    logic        noc_tx         [(NPORT - 1):0];
    logic        noc_credit_snd [(NPORT - 1):0];
    logic [31:0] noc_data_snd   [(NPORT - 1):0];

    assign noc_tx_o                      = noc_tx[(NPORT - 2):0];
    assign noc_credit_snd[(NPORT - 2):0] = noc_credit_i;
    assign noc_data_o                    = noc_data_snd[(NPORT - 2):0];

    HermesRouter #(
        .ADDRESS(ADDRESS),
        .BUFFER_SIZE(8),
        .FLIT_SIZE(32)
    )
    router (
        .clk_i    (clk_i         ),
        .rst_ni   (rst_ni        ),
        .rx_i     (noc_rx        ),
        .credit_i (noc_credit_snd),
        .data_i   (noc_data_rcv  ),
        .tx_o     (noc_tx        ),
        .credit_o (noc_credit_rcv),
        .data_o   (noc_data_snd  )
    );

////////////////////////////////////////////////////////////////////////////////
// BrNoC
////////////////////////////////////////////////////////////////////////////////

    logic brlite_local_busy;

    logic     brlite_req_rcv  [(NPORT - 1):0];
    logic     brlite_ack_rcv  [(NPORT - 1):0];
    br_data_t brlite_flit_rcv [(NPORT - 1):0];

    assign brlite_req_rcv[(NPORT - 2):0]  = brlite_req_i;
    assign brlite_ack_rcv                 = brlite_ack_o[(NPORT - 2):0];
    assign brlite_flit_rcv[(NPORT - 2):0] = brlite_flit_i;

    logic     brlite_req_snd  [(NPORT - 1):0];
    logic     brlite_ack_snd  [(NPORT - 1):0];
    br_data_t brlite_flit_snd [(NPORT - 1):0];

    assign brlite_req_o                  = brlite_req_snd[(NPORT - 2):0];
    assign brlite_ack_snd[(NPORT - 2):0] = brlite_ack_i;
    assign brlite_flit_o                 = brlite_flit_snd[(NPORT - 2):0];

    BrLiteRouter #(
        .SEQ_ADDRESS (SEQ_ADDRESS),
        .CAM_SIZE    (8          ),
        .CLEAR_TICKS (150        )
    )
    br_router (
        .clk_i        (clk_i            ),
        .rst_ni       (rst_ni           ),
        .tick_cnt_i   (mtime            ),
        .local_busy_o (brlite_local_busy),
        .flit_i       (brlite_flit_rcv  ),
        .req_i        (brlite_req_rcv   ),
        .ack_o        (brlite_ack_rcv   ),
        .flit_o       (brlite_flit_snd  ),
        .req_o        (brlite_req_snd   ),
        .ack_i        (brlite_ack_snd   ),
    );

////////////////////////////////////////////////////////////////////////////////
// DMNI
////////////////////////////////////////////////////////////////////////////////

    logic        dmni_irq;     /* @todo */

    logic        ni_en;
    logic [31:0] ni_data_read;

    logic [3:0]  dma_we;         /* @todo */
    logic [31:0] dma_addr;       /* @todo */
    logic [31:0] dma_data_write; /* @todo */
    logic [31:0] dma_data_read;  /* @todo */

    logic        brlite_mon_req;
    logic        brlite_mon_ack;
    brlite_mon_t brlite_mon_flit;

    assign brlite_mon_req             = brlite_req_snd[(NPORT - 1)] && (brlite_flit_snd[(NPORT - 1)].service == BR_SVC_MON);
    assign brlite_mon_flit.payload    = brlite_flit_snd[(NPORT - 1)].payload;
    assign brlite_mon_flit.seq_source = brlite_flit_snd[(NPORT - 1)].seq_source;
    assign brlite_mon_flit.producer   = brlite_flit_snd[(NPORT - 1)].producer;
    assign brlite_mon_flit.msvc       = brlite_flit_snd[(NPORT - 1)].ksvc[($clog2(BRLITE_MON_NSVC) - 1):0];

    logic        brlite_svc_req;
    logic        brlite_svc_ack;
    brlite_svc_t brlite_svc_flit;

    assign brlite_svc_req = brlite_req_snd[(NPORT - 1)] && (brlite_flit_snd[(NPORT - 1)].service != BR_SVC_MON);
    assign brlite_svc_flit.payload    = brlite_flit_snd[(NPORT - 1)].payload;
    assign brlite_svc_flit.seq_source = brlite_flit_snd[(NPORT - 1)].seq_source;
    assign brlite_svc_flit.producer   = brlite_flit_snd[(NPORT - 1)].producer;
    assign brlite_svc_flit.ksvc       = brlite_flit_snd[(NPORT - 1)].ksvc;

    assign brlite_ack_snd = (brlite_flit_snd[(NPORT - 1)].service == BR_SVC_MON) ? brlite_mon_ack : brlite_svc_ack;

    logic [4:0] brlite_id;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            brlite_id <= '0;
        else if (brlite_ack_rcv[(NPORT - 1)])
            brlite_id <= brlite_id + 1'b1;
    end

    brlite_out_t brlite_flit_ni;

    assign brlite_flit_rcv[(NPORT - 1)].payload    = brlite_flit_ni.payload;
    assign brlite_flit_rcv[(NPORT - 1)].seq_target = brlite_flit_ni.seq_target;
    assign brlite_flit_rcv[(NPORT - 1)].seq_source = SEQ_ADDRESS;
    assign brlite_flit_rcv[(NPORT - 1)].producer   = brlite_flit_ni.producer;
    assign brlite_flit_rcv[(NPORT - 1)].ksvc       = brlite_flit_ni.ksvc;
    assign brlite_flit_rcv[(NPORT - 1)].id         = brlite_id;
    assign brlite_flit_rcv[(NPORT - 1)].service    = brlite_flit_ni.service;

    DMNI #(
        .HERMES_FLIT_SIZE   (32),
        .HERMES_BUFFER_SIZE (16),
        .BR_MON_BUFFER_SIZE (8),
        .BR_SVC_BUFFER_SIZE (4),
        .N_PE               (N_PE),
        .TASKS_PER_PE       (TASKS_PER_PE)
    )
    dmni (
        .clk_i           (clk_i                       ),
        .rst_ni          (rst_ni                      ),
        .irq_o           (dmni_irq                    ),
        .cfg_en_i        (ni_en                       ),
        .cfg_we_i        (cpu_we                      ),
        .cfg_addr_i      (cpu_addr                    ),
        .cfg_data_i      (cpu_data_write              ),
        .cfg_data_o      (ni_data_read                ),
        .mem_we_o        (dma_we                      ),
        .mem_addr_o      (dma_addr                    ),
        .mem_data_o      (dma_data_write              ),
        .mem_data_i      (dma_data_read               ),
        .noc_rx_i        (noc_tx[(NPORT - 1)]         ),
        .noc_credit_o    (noc_credit_snd[(NPORT - 1)] ),
        .noc_data_i      (noc_data_snd[(NPORT - 1)]   ),
        .noc_tx_o        (noc_rx[(NPORT - 1)]         ),
        .noc_credit_i    (noc_credit_rcv[(NPORT - 1)] ),
        .noc_data_o      (noc_data_rcv[(NPORT - 1)]   ),
        .br_req_mon_i    (brlite_mon_req              ),
        .br_ack_mon_o    (brlite_mon_ack              ),
        .br_mon_data_i   (brlite_mon_flit             ),
        .br_req_svc_i    (brlite_svc_req              ),
        .br_ack_svc_o    (brlite_svc_ack              ),
        .br_svc_data_i   (brlite_svc_flit             ),
        .br_local_busy_i (brlite_local_busy           ),
        .br_req_o        (brlite_req_rcv[(NPORT - 1)] ),
        .br_ack_i        (brlite_ack_rcv[(NPORT - 1)] ),
        .br_data_o       (brlite_flit_ni              )
    );

////////////////////////////////////////////////////////////////////////////////
// Memory address multiplexing
////////////////////////////////////////////////////////////////////////////////

    /**
     * Memory map:
     * [0x00000000, 0x80000000[ (bit 31 = 0) -> instruction
     * [0x80000000, 0xFFFFFFFF] (bit 31 = 1) -> data
     *  [0x80000000, 0xC0000000[ (bit 30 = 0) -> data memory
     *  [0xC1000000, 0xFFFFFFFF] (bit 30 = 1) -> MMR
     *   [0xC1000000, 0xC2000000[ (bit 24 = 1) -> PLIC
     *   [0xC2000000, 0xC3000000[ (bit 25 = 1) -> RTC
     *   [0xC4000000, 0xC5000000[ (bit 26 = 1) -> NI
     *   [0xC8000000, 0xC9000000[ (bit 27 = 1) -> Reserved
     *   [0xD0000000, 0xD1000000[ (bit 28 = 1) -> Reserved
     *   [0xE0000000, 0xE1000000[ (bit 29 = 1) -> Reserved
     */

    assign dmem_en_o = cpu_en && (cpu_addr <= 32'h00000000);
    assign rtc_en    = cpu_en && (cpu_addr >  32'h00000000 && cpu_addr <= 32'h00000000);
    assign plic_en   = cpu_en && (cpu_addr >  32'h00000000 && cpu_addr <= 32'h00000000);
    assign ni_en     = cpu_en && (cpu_addr >  32'h00000000 && cpu_addr <= 32'h00000000);

    /* On read, the data is available at the next cycle */
    logic rtc_en_r;
    logic plic_en_r;
    logic ni_en_r;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rtc_en_r  <= '0;
            plic_en_r <= '0;
            ni_en_r   <= '0;
        end
        else begin
            rtc_en_r  <= rtc_en;
            plic_en_r <= plic_en;
            ni_en_r   <= plic_en;
        end;
    end

    always_comb begin
        if (rtc_en_r)
            cpu_data_read <= rtc_data_read;
        else if (plic_en_r)
            cpu_data_read <= plic_data_read;
        else if (ni_en_r)
            cpu_data_read <= ni_data_read;
        else
            cpu_data_read <= dmem_data_i;
    end

endmodule
