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
    parameter logic [15:0]  ADDRESS      = 16'b0,
    parameter logic [15:0]  SEQ_ADDRESS  = 0,
    parameter               N_PE_X       = 2,
    parameter               N_PE_Y       = 2,
    parameter               TASKS_PER_PE = 1,
    parameter               IMEM_PAGE_SZ = 32768,
    parameter               DMEM_PAGE_SZ = 32768,
    parameter               DEBUG        = 1,
    parameter environment_e Environment  = ASIC
)
(
    input  logic                        clk_i,
    input  logic                        rst_ni,

    /* Instruction memory interface: read-only */
    output logic     [23:0]             imem_addr_o,
    input  logic     [31:0]             imem_data_i,

    /* Data memory interface: read/write */
    output logic                        dmem_en_o,
    output logic     [3:0]              dmem_we_o,
    output logic     [23:0]             dmem_addr_o,
    input  logic     [31:0]             dmem_data_i,
    output logic     [31:0]             dmem_data_o,

    /* DMA memory interface: read/write on instruction/data */
    output logic                        idma_en_o,
    output logic                        ddma_en_o,
    output logic     [3:0]              dma_we_o,
    output logic     [23:0]             dma_addr_o,
    input  logic     [31:0]             idma_data_i,
    input  logic     [31:0]             ddma_data_i,
    output logic     [31:0]             dma_data_o,

    /* NoC input interface */
    output logic                        release_peripheral_o,
    input  logic                        noc_rx_i              [(HERMES_NPORT - 2):0],
    output logic                        noc_credit_o          [(HERMES_NPORT - 2):0],
    input  logic     [31:0]             noc_data_i            [(HERMES_NPORT - 2):0],

    /* NoC output interface */
    output logic                        noc_tx_o              [(HERMES_NPORT - 2):0],
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
    logic [31:0] irq;

    assign irq = {20'b0, mei, 3'b0, mti, 7'b0};

    logic        irq_ack;
    logic        cpu_en;
    logic [3:0]  cpu_we;
    logic [31:0] cpu_addr;
    logic [31:0] cpu_data_write;
    logic [31:0] cpu_data_read;
    logic [63:0] mtime;

    /* The CPU is 32 bits but not all bits are used in memory */
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] imem_addr;
    /* verilator lint_on UNUSEDSIGNAL */

    assign imem_addr_o = imem_addr[23:0];
    assign dmem_we_o   = cpu_we;
    assign dmem_addr_o = cpu_addr[23:0];
    assign dmem_data_o = cpu_data_write;

    RS5 #(
        .Environment(Environment),
        .RV32(RV32ZMMUL),
        .XOSVMEnable(1),
        .ZIHPMEnable(1)
    )
    processor (
        .clk                    (clk_i         ),
        .reset_n                (rst_ni        ),
        .stall                  (1'b0          ),
        .instruction_i          (imem_data_i   ),
        .mem_data_i             (cpu_data_read ),
        .mtime_i                (mtime         ),
        .irq_i                  (irq           ),
        .instruction_address_o  (imem_addr     ),
        .mem_operation_enable_o (cpu_en        ),
        .mem_write_enable_o     (cpu_we        ),
        .mem_address_o          (cpu_addr      ),
        .mem_data_o             (cpu_data_write),
        .interrupt_ack_o        (irq_ack       )
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
    logic [31:0] plic_data_read;

    plic #(
        .i_cnt(1)
    )
    plic_m (
        .clk    (clk_i         ),
        .reset_n(rst_ni        ),
        .en_i   (plic_en       ),
        .we_i   (cpu_we        ),
        .addr_i (cpu_addr[23:0]),
        .data_i (cpu_data_write),
        .data_o (plic_data_read),
        .irq_i  (dmni_irq      ),
        .iack_i (irq_ack       ),
        .iack_o (plic_ack      ),
        .irq_o  (mei           )
    );

////////////////////////////////////////////////////////////////////////////////
// RTC
////////////////////////////////////////////////////////////////////////////////

    logic        rtc_en;
    
    /* The RTC bus is 64 bits, while the CPU bus is 32 bits */
    /* verilator lint_off UNUSEDSIGNAL */
    logic [63:0] rtc_data_read;
    /* verilator lint_on UNUSEDSIGNAL */

    rtc 
    rtc_m (
        .clk     (clk_i                  ),
        .reset_n (rst_ni                 ),
        .en_i    (rtc_en                 ),
        .addr_i  (cpu_addr[3:0]          ),
        .we_i    ({4'h0, cpu_we}         ),
        .data_i  ({32'h0, cpu_data_write}),
        .data_o  (rtc_data_read          ),
        .mti_o   (mti                    ),
        .mtime_o (mtime                  )
    );

////////////////////////////////////////////////////////////////////////////////
// NoC
////////////////////////////////////////////////////////////////////////////////

    logic        noc_rx         [(HERMES_NPORT - 1):0];
    logic        noc_credit_rcv [(HERMES_NPORT - 1):0];
    logic [31:0] noc_data_rcv   [(HERMES_NPORT - 1):0];

    assign noc_rx[(HERMES_NPORT - 2):0]       = noc_rx_i;
    assign noc_credit_o                       = noc_credit_rcv[(HERMES_NPORT - 2):0];
    assign noc_data_rcv[(HERMES_NPORT - 2):0] = noc_data_i;

    logic        noc_tx         [(HERMES_NPORT - 1):0];
    logic        noc_credit_snd [(HERMES_NPORT - 1):0];
    logic [31:0] noc_data_snd   [(HERMES_NPORT - 1):0];

    assign noc_tx_o                             = noc_tx[(HERMES_NPORT - 2):0];
    assign noc_credit_snd[(HERMES_NPORT - 2):0] = noc_credit_i;
    assign noc_data_o                           = noc_data_snd[(HERMES_NPORT - 2):0];

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

    logic     [(BR_NPORT - 1):0] brlite_req_rcv;
    logic     [(BR_NPORT - 1):0] brlite_ack_rcv;
    br_data_t [(BR_NPORT - 1):0] brlite_flit_rcv;

    assign brlite_req_rcv[(BR_NPORT - 2):0]  = brlite_req_i;
    assign brlite_ack_o                      = brlite_ack_rcv[(BR_NPORT - 2):0];
    assign brlite_flit_rcv[(BR_NPORT - 2):0] = brlite_flit_i;

    logic     [(BR_NPORT - 1):0] brlite_req_snd;
    logic     [(BR_NPORT - 1):0] brlite_ack_snd;
    br_data_t [(BR_NPORT - 1):0] brlite_flit_snd;

    assign brlite_req_o                     = brlite_req_snd[(BR_NPORT - 2):0];
    assign brlite_ack_snd[(BR_NPORT - 2):0] = brlite_ack_i;
    assign brlite_flit_o                    = brlite_flit_snd[(BR_NPORT - 2):0];

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
        .ack_i        (brlite_ack_snd   )
    );

////////////////////////////////////////////////////////////////////////////////
// DMNI
////////////////////////////////////////////////////////////////////////////////

    logic        ni_en;
    logic        ni_we;
    logic [31:0] ni_data_read;

    assign ni_we = (| cpu_we);

    logic [3:0]  dma_we;
    logic [31:0] dma_addr;
    logic [31:0] dma_data_read;

    assign idma_en_o  = (dma_addr[31:24] == 8'b00000000);
    assign ddma_en_o  = (dma_addr[31:24] == 8'b00000001);
    assign dma_we_o   = dma_we;
    assign dma_addr_o = dma_addr[23:0];

    always_comb begin
        if (dma_addr[31:25] == '0)
            dma_data_read = dma_addr[24] ? ddma_data_i : idma_data_i;
        else
            dma_data_read = '0;
    end

    logic        brlite_mon_req;
    logic        brlite_mon_ack;
    brlite_mon_t brlite_mon_flit;

    assign brlite_mon_req             = brlite_req_snd[(BR_NPORT - 1)] && (brlite_flit_snd[(BR_NPORT - 1)].service == BR_SVC_MON);
    assign brlite_mon_flit.payload    = brlite_flit_snd[(BR_NPORT - 1)].payload;
    assign brlite_mon_flit.seq_source = brlite_flit_snd[(BR_NPORT - 1)].seq_source;
    assign brlite_mon_flit.producer   = brlite_flit_snd[(BR_NPORT - 1)].producer;
    assign brlite_mon_flit.msvc       = brlite_flit_snd[(BR_NPORT - 1)].ksvc[($clog2(BRLITE_MON_NSVC) - 1):0];

    logic        brlite_svc_req;
    logic        brlite_svc_ack;
    brlite_svc_t brlite_svc_flit;

    assign brlite_svc_req = brlite_req_snd[(BR_NPORT - 1)] && (brlite_flit_snd[(BR_NPORT - 1)].service != BR_SVC_MON);
    assign brlite_svc_flit.payload    = brlite_flit_snd[(BR_NPORT - 1)].payload;
    assign brlite_svc_flit.seq_source = brlite_flit_snd[(BR_NPORT - 1)].seq_source;
    assign brlite_svc_flit.producer   = brlite_flit_snd[(BR_NPORT - 1)].producer;
    assign brlite_svc_flit.ksvc       = brlite_flit_snd[(BR_NPORT - 1)].ksvc;

    assign brlite_ack_snd[(BR_NPORT - 1)] = (brlite_flit_snd[(BR_NPORT - 1)].service == BR_SVC_MON) ? brlite_mon_ack : brlite_svc_ack;

    logic [4:0] brlite_id;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            brlite_id <= '0;
        else if (brlite_ack_rcv[(BR_NPORT - 1)])
            brlite_id <= brlite_id + 1'b1;
    end

    brlite_out_t brlite_flit_ni;

    assign brlite_flit_rcv[(BR_NPORT - 1)].payload    = brlite_flit_ni.payload;
    assign brlite_flit_rcv[(BR_NPORT - 1)].seq_target = brlite_flit_ni.seq_target;
    assign brlite_flit_rcv[(BR_NPORT - 1)].seq_source = SEQ_ADDRESS;
    assign brlite_flit_rcv[(BR_NPORT - 1)].producer   = brlite_flit_ni.producer;
    assign brlite_flit_rcv[(BR_NPORT - 1)].ksvc       = brlite_flit_ni.ksvc;
    assign brlite_flit_rcv[(BR_NPORT - 1)].id         = brlite_id;
    assign brlite_flit_rcv[(BR_NPORT - 1)].service    = br_svc_t'(brlite_flit_ni.service);

    DMNI #(
        .HERMES_FLIT_SIZE   (32          ),
        .HERMES_BUFFER_SIZE (16          ),
        .BR_MON_BUFFER_SIZE (8           ),
        .BR_SVC_BUFFER_SIZE (4           ),
        .N_PE_X             (N_PE_X      ),
        .N_PE_Y             (N_PE_Y      ),
        .TASKS_PER_PE       (TASKS_PER_PE),
        .IMEM_PAGE_SZ       (IMEM_PAGE_SZ),
        .DMEM_PAGE_SZ       (DMEM_PAGE_SZ),
        .ADDRESS            (ADDRESS     )
    )
    dmni (
        .clk_i                (clk_i                                  ),
        .rst_ni               (rst_ni                                 ),
        .irq_o                (dmni_irq                               ),
        .cfg_en_i             (ni_en                                  ),
        .cfg_we_i             (ni_we                                  ),
        .cfg_addr_i           (cpu_addr[($clog2(DMNI_MMR_SIZE) + 1):2]),
        .cfg_data_i           (cpu_data_write                         ),
        .cfg_data_o           (ni_data_read                           ),
        .release_peripheral_o (release_peripheral_o                   ),
        .mem_we_o             (dma_we                                 ),
        .mem_addr_o           (dma_addr                               ),
        .mem_data_o           (dma_data_o                             ),
        .mem_data_i           (dma_data_read                          ),
        .noc_rx_i             (noc_tx[(HERMES_NPORT - 1)]             ),
        .noc_credit_o         (noc_credit_snd[(HERMES_NPORT - 1)]     ),
        .noc_data_i           (noc_data_snd[(HERMES_NPORT - 1)]       ),
        .noc_tx_o             (noc_rx[(HERMES_NPORT - 1)]             ),
        .noc_credit_i         (noc_credit_rcv[(HERMES_NPORT - 1)]     ),
        .noc_data_o           (noc_data_rcv[(HERMES_NPORT - 1)]       ),
        .br_req_mon_i         (brlite_mon_req                         ),
        .br_ack_mon_o         (brlite_mon_ack                         ),
        .br_mon_data_i        (brlite_mon_flit                        ),
        .br_req_svc_i         (brlite_svc_req                         ),
        .br_ack_svc_o         (brlite_svc_ack                         ),
        .br_svc_data_i        (brlite_svc_flit                        ),
        .br_local_busy_i      (brlite_local_busy                      ),
        .br_req_o             (brlite_req_rcv[(BR_NPORT - 1)]         ),
        .br_ack_i             (brlite_ack_rcv[(BR_NPORT - 1)]         ),
        .br_data_o            (brlite_flit_ni                         )
    );

////////////////////////////////////////////////////////////////////////////////
// Memory address multiplexing
////////////////////////////////////////////////////////////////////////////////

    /**
     * Memory map:
     * [0x00000000, 0x01000000[ -> instruction
     * [0x01000000, 0x02000000[ -> data
     * [0x02000000, 0x03000000[ -> RTC
     * [0x04000000, 0x05000000[ -> PLIC
     * [0x08000000, 0x09000000[ -> NI
     * [0x10000000, 0x11000000[ -> Reserved 4
     * [0x20000000, 0x21000000[ -> Reserved 5
     * [0x40000000, 0x41000000[ -> Reserved 6
     * [0x80000000, 0x81000000[ -> DEBUG
     */

    assign dmem_en_o = cpu_en && (cpu_addr[31:24] == 8'b00000001);
    assign rtc_en    = cpu_en && (cpu_addr[31:24] == 8'b00000010);
    assign plic_en   = cpu_en && (cpu_addr[31:24] == 8'b00000100);
    assign ni_en     = cpu_en && (cpu_addr[31:24] == 8'b00001000);

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
            ni_en_r   <= ni_en;
        end;
    end

    always_comb begin
        if (rtc_en_r)
            cpu_data_read = rtc_data_read[31:0];
        else if (plic_en_r)
            cpu_data_read = plic_data_read;
        else if (ni_en_r)
            cpu_data_read = ni_data_read;
        else
            cpu_data_read = dmem_data_i;
    end

////////////////////////////////////////////////////////////////////////////////
// UART and DEBUG connections
////////////////////////////////////////////////////////////////////////////////

    if (DEBUG) begin : gen_pe_debug
        logic dbg_en;
        logic dbg_we;

        assign dbg_en = cpu_en && (cpu_addr[31:24] == 8'b10000000);
        assign dbg_we = (| cpu_we);
        
        Debug #(
            .ADDRESS (ADDRESS)
        )
        dbg (
            .clk_i  (clk_i         ),
            .rst_ni (rst_ni        ),
            .en_i   (dbg_en        ),
            .we_i   (dbg_we        ),
            .addr_i (cpu_addr[23:0]),
            .data_i (cpu_data_write)
        );
    end

endmodule
