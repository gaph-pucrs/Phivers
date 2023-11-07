module PhiversMC
    import RS5_pkg::*;
    import HermesPkg::*;
    import BrLitePkg::*;
#(
    parameter               N_PE_X       = 4,
    parameter               N_PE_Y       = 4,
    parameter               TASKS_PER_PE = 4,
    parameter logic [15:0]  ADDR_MA_INJ  = 16'h0000,
    parameter hermes_port_t PORT_MA_INJ  = HERMES_SOUTH,
    parameter logic [15:0]  ADDR_APP_INJ = 16'h0100,
    parameter hermes_port_t PORT_APP_INJ = HERMES_SOUTH,
    parameter environment_e Environment  = ASIC
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic [15:0] mapper_address_i,

    input  logic        ma_src_rx_i,
    output logic        ma_src_credit_o,
    input  logic [31:0] ma_src_data_i,

    input  logic        app_src_rx_i,
    output logic        app_src_credit_o,
    input  logic [31:0] app_src_data_i,

    /* Instruction memory interface: read-only */
    output logic [23:0] imem_addr_o       [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    input  logic [31:0] imem_data_i       [(N_PE_X - 1):0][(N_PE_Y - 1):0],

    /* Data memory interface: read/write */
    output logic        dmem_en_o         [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    output logic [3:0]  dmem_we_o         [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    output logic [23:0] dmem_addr_o       [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    input  logic [31:0] dmem_data_i       [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    output logic [31:0] dmem_data_o       [(N_PE_X - 1):0][(N_PE_Y - 1):0],

    /* DMA memory interface: read/write on instruction/data */
    output logic        idma_en_o         [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    output logic        ddma_en_o         [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    output logic [3:0]  dma_we_o          [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    output logic [23:0] dma_addr_o        [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    input  logic [31:0] idma_data_i       [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    input  logic [31:0] ddma_data_i       [(N_PE_X - 1):0][(N_PE_Y - 1):0],
    output logic [31:0] dma_data_o        [(N_PE_X - 1):0][(N_PE_Y - 1):0]
);

    localparam n_pe = N_PE_X * N_PE_Y;

////////////////////////////////////////////////////////////////////////////////
// MA Injector
////////////////////////////////////////////////////////////////////////////////

    logic        ma_inj_tx;
    logic        ma_inj_credit_tx;
    logic [31:0] ma_inj_data_tx;

    logic        ma_inj_rx;
    logic        ma_inj_credit_rx;
    logic [31:0] ma_inj_data_rx;

    TaskInjector #(
        .INJECTOR_ADDRESS (ADDR_MA_INJ),
        .FLIT_SIZE        (32         ),
        .MAX_PAYLOAD_SIZE (32         ),
        .INJECT_MAPPER    (1          )
    )
    MAInjector (
        .clk_i           (clk_i           ),
        .rst_ni          (rst_ni          ),
        .src_rx_i        (ma_src_rx_i     ),
        .src_credit_o    (ma_src_credit_o ),
        .src_data_i      (ma_src_data_i   ),
        .mapper_address_i(mapper_address_i),
        .noc_tx_o        (ma_inj_tx       ),
        .noc_credit_i    (ma_inj_credit_tx),
        .noc_data_o      (ma_inj_data_tx  ),
        .noc_rx_i        (ma_inj_rx       ),
        .noc_credit_o    (ma_inj_credit_rx),
        .noc_data_i      (ma_inj_data_rx  )
    );

////////////////////////////////////////////////////////////////////////////////
// App Injector
////////////////////////////////////////////////////////////////////////////////

    logic        app_inj_tx;
    logic        app_inj_credit_tx;
    logic [31:0] app_inj_data_tx;

    logic        app_inj_rx;
    logic        app_inj_credit_rx;
    logic [31:0] app_inj_data_rx;

    TaskInjector #(
        .INJECTOR_ADDRESS(ADDR_APP_INJ),
        .FLIT_SIZE(32),
        .MAX_PAYLOAD_SIZE(32),
        .INJECT_MAPPER(0)
    )
    AppInjector (
        .clk_i           (clk_i            ),
        .rst_ni          (rst_ni           ),
        .src_rx_i        (app_src_rx_i     ),
        .src_credit_o    (app_src_credit_o ),
        .src_data_i      (app_src_data_i   ),
        .mapper_address_i(mapper_address_i ),
        .noc_tx_o        (app_inj_tx       ),
        .noc_credit_i    (app_inj_credit_tx),
        .noc_data_o      (app_inj_data_tx  ),
        .noc_rx_i        (app_inj_rx       ),
        .noc_credit_o    (app_inj_credit_rx),
        .noc_data_i      (app_inj_data_rx  )
    );

////////////////////////////////////////////////////////////////////////////////
// Add new peripherals here
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// Many-core Injector
////////////////////////////////////////////////////////////////////////////////

    /* Hermes signals */
    logic        release_peripheral [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        rx                 [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic        credit_rx          [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic [31:0] data_rx            [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];

    logic        tx                 [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic        credit_tx          [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic [31:0] data_tx            [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];

    /* BrLite signals */
    logic        req_rx             [(N_PE_X - 1):0][(N_PE_Y - 1):0][(BR_NPORT - 2):0];
    logic        ack_rx             [(N_PE_X - 1):0][(N_PE_Y - 1):0][(BR_NPORT - 2):0];
    br_data_t    flit_rx            [(N_PE_X - 1):0][(N_PE_Y - 1):0][(BR_NPORT - 2):0];

    logic        req_tx             [(N_PE_X - 1):0][(N_PE_Y - 1):0][(BR_NPORT - 2):0];
    logic        ack_tx             [(N_PE_X - 1):0][(N_PE_Y - 1):0][(BR_NPORT - 2):0];
    br_data_t    flit_tx            [(N_PE_X - 1):0][(N_PE_Y - 1):0][(BR_NPORT - 2):0];

    generate
        for (genvar x = 0; x < N_PE_X; x++) begin : gen_x
            for (genvar y = 0; y < N_PE_Y; y++) begin : gen_y
                localparam logic [15:0] address  = {x[7:0], y[7:0]};
                localparam logic [15:0] seq_addr = y * N_PE_X + x;

                PhiversPE #(
                    .ADDRESS(address),
                    .SEQ_ADDRESS(seq_addr),
                    .N_PE(n_pe),
                    .TASKS_PER_PE(TASKS_PER_PE),
                    .Environment(Environment)
                ) 
                pe (
                    .clk_i                (clk_i                   ),
                    .rst_ni               (rst_ni                  ),
                    .imem_addr_o          (imem_addr_o[x][y]       ),
                    .imem_data_i          (imem_data_i[x][y]       ),
                    .dmem_en_o            (dmem_en_o[x][y]         ),
                    .dmem_we_o            (dmem_we_o[x][y]         ),
                    .dmem_addr_o          (dmem_addr_o[x][y]       ),
                    .dmem_data_i          (dmem_data_i[x][y]       ),
                    .dmem_data_o          (dmem_data_o[x][y]       ),
                    .idma_en_o            (idma_en_o[x][y]         ),
                    .ddma_en_o            (ddma_en_o[x][y]         ),
                    .dma_we_o             (dma_we_o[x][y]          ),
                    .dma_addr_o           (dma_addr_o[x][y]        ),
                    .idma_data_i          (idma_data_i[x][y]       ),
                    .ddma_data_i          (ddma_data_i[x][y]       ),
                    .dma_data_o           (dma_data_o[x][y]        ),
                    .release_peripheral_o (release_peripheral[x][y]),
                    .noc_rx_i             (rx[x][y]                ),
                    .noc_credit_o         (credit_rx[x][y]         ),
                    .noc_data_i           (data_rx[x][y]           ),
                    .noc_tx_i             (tx[x][y]                ),
                    .noc_credit_i         (credit_tx[x][y]         ),
                    .noc_data_o           (data_tx[x][y]           ),
                    .brlite_req_i         (req_rx[x][y]            ),
                    .brlite_ack_o         (ack_rx[x][y]            ),
                    .brlite_flit_i        (flit_rx[x][y]           ),
                    .brlite_req_o         (req_tx[x][y]            ),
                    .brlite_ack_i         (ack_tx[x][y]            ),
                    .brlite_flit_o        (flit_tx[x][y]           )
                );

                /* Hermes connection */
                always_comb begin
                    rx[x][y][HERMES_EAST]            = (x != N_PE_X - 1) ? tx[x + 1][y][HERMES_WEST]      : '0;
                    credit_tx[x + 1][y][HERMES_WEST] = (x != N_PE_X - 1) ? credit_rx[x][y][HERMES_EAST]   : '0;
                    data_rx[x][y][HERMES_EAST]       = (x != N_PE_X - 1) ? data_tx[x + 1][y][HERMES_WEST] : '0;

                    rx[x][y][HERMES_WEST]            = (x != 0) ? tx[x - 1][y][HERMES_EAST]      : '0;
                    credit_tx[x - 1][y][HERMES_EAST] = (x != 0) ? credit_rx[x][y][HERMES_WEST]   : '0;
                    data_rx[x][y][HERMES_WEST]       = (x != 0) ? data_tx[x - 1][y][HERMES_EAST] : '0;

                    rx[x][y][HERMES_NORTH]            = (y != N_PE_Y - 1) ? tx[x][y + 1][HERMES_SOUTH]      : '0;
                    credit_tx[x][y + 1][HERMES_SOUTH] = (y != N_PE_Y - 1) ? credit_rx[x][y][HERMES_NORTH]   : '0;
                    data_rx[x][y][HERMES_NORTH]       = (y != N_PE_Y - 1) ? data_tx[x][y + 1][HERMES_SOUTH] : '0;

                    rx[x][y][HERMES_SOUTH]            = (y != 0) ? tx[x][y - 1][HERMES_NORTH]      : '0;
                    credit_tx[x][y - 1][HERMES_NORTH] = (y != 0) ? credit_rx[x][y][HERMES_SOUTH]   : '0;
                    data_rx[x][y][HERMES_SOUTH]       = (y != 0) ? data_tx[x][y - 1][HERMES_NORTH] : '0;

                    if (address == ADDR_MA_INJ) begin
                        rx[x][y][PORT_MA_INJ]      = ma_inj_tx;
                        ma_inj_credit_tx           = credit_rx[x][y][PORT_MA_INJ];
                        data_rx[x][y][PORT_MA_INJ] = ma_inj_data_tx;

                        ma_inj_rx                    = tx[x][y][PORT_MA_INJ];
                        credit_tx[x][y][PORT_MA_INJ] = ma_inj_credit_rx;
                        ma_inj_data_rx               = data_tx[x][y][PORT_MA_INJ];
                    end

                    if (address == ADDR_APP_INJ) begin
                        rx[x][y][PORT_APP_INJ]      = app_inj_tx && release_peripheral[x][y];
                        app_inj_credit_tx           = credit_rx[x][y][PORT_APP_INJ];
                        data_rx[x][y][PORT_APP_INJ] = app_inj_data_tx;

                        app_inj_rx                    = tx[x][y][PORT_APP_INJ] && release_peripheral[x][y];
                        credit_tx[x][y][PORT_APP_INJ] = app_inj_credit_rx;
                        app_inj_data_rx               = data_tx[x][y][PORT_APP_INJ];
                    end

                    /* Insert the IO wiring for your component here if it connected to a port */
                end

                /* BrLite connection */
                assign req_rx[x][y][BR_EAST]     = (x != N_PE_X - 1) ? req_tx[x + 1][y][BR_WEST]  : '0;
                assign ack_tx[x + 1][y][BR_WEST] = (x != N_PE_X - 1) ? ack_rx[x][y][BR_EAST]      : '0;
                assign flit_rx[x][y][BR_EAST]    = (x != N_PE_X - 1) ? flit_tx[x + 1][y][BR_WEST] : '0;

                assign req_rx[x][y][BR_WEST]     = (x != 0) ? req_tx[x - 1][y][BR_EAST]  : '0;
                assign ack_tx[x - 1][y][BR_EAST] = (x != 0) ? ack_rx[x][y][BR_WEST]      : '0;
                assign flit_rx[x][y][BR_WEST]    = (x != 0) ? flit_tx[x - 1][y][BR_EAST] : '0;

                assign req_rx[x][y][BR_NORTH]     = (y != N_PE_Y - 1) ? req_tx[x][y + 1][BR_SOUTH]  : '0;
                assign ack_tx[x][y + 1][BR_SOUTH] = (y != N_PE_Y - 1) ? ack_rx[x][y][BR_NORTH]      : '0;
                assign flit_rx[x][y][BR_NORTH]    = (y != N_PE_Y - 1) ? flit_tx[x][y + 1][BR_SOUTH] : '0;

                assign req_rx[x][y][BR_SOUTH]     = (y != 0) ? req_tx[x][y - 1][BR_NORTH]  : '0;
                assign ack_tx[x][y - 1][BR_NORTH] = (y != 0) ? ack_rx[x][y][BR_SOUTH]      : '0;
                assign flit_rx[x][y][BR_SOUTH]    = (y != 0) ? flit_tx[x][y - 1][BR_NORTH] : '0;
            end
        end
    endgenerate

endmodule
