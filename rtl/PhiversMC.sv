`include "../RS5/rtl/RS5_pkg.sv"
`include "../Hermes/rtl/HermesPkg.sv"
`include "../BrLite/rtl/BrLitePkg.sv"

module PhiversMC
    import RS5_pkg::*;
    import HermesPkg::*;
    import BrLitePkg::*;
#(
    parameter               N_PE_X                                    = 4,
    parameter               N_PE_Y                                    = 4,
    parameter               TASKS_PER_PE                              = 4,
    parameter               IMEM_PAGE_SZ                              = 32768,
    parameter               DMEM_PAGE_SZ                              = 32768,
    parameter               RS5_DEBUG                                 = 0,
    parameter logic [15:0]  ADDR_MA_INJ                               = 16'h0000,
    parameter hermes_port_t PORT_MA_INJ                               = HERMES_SOUTH,
    parameter logic [15:0]  ADDR_APP_INJ                              = 16'h0100,
    parameter hermes_port_t PORT_APP_INJ                              = HERMES_SOUTH,
    parameter environment_e Environment                               = ASIC,
    parameter bit           UART_DEBUG                                = 1,
    parameter bit           SCHED_DEBUG                               = 1,
    parameter bit           PIPE_DEBUG                                = 1,
    parameter bit           TRAFFIC_DEBUG                             = 1,
    parameter bit           DMNI_DEBUG                                = 0,
    parameter string        LINK_CFG     [N_PE_X*N_PE_Y*HERMES_NPORT] = '{default: ""}
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic [15:0] mapper_address_i,

    input  logic        ma_src_rx_i,
    output logic        ma_src_credit_o,
    input  logic [31:0] ma_src_data_i,

    input  logic        app_src_eoa_i,
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

    /* Hermes signals */
    logic                           release_peripheral [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic                           rx                 [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic                           eop_rx             [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic                           credit_rx          [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic        [31:0]             data_rx            [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];

    logic                           tx                 [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic                           eop_tx             [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic                           credit_tx          [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];
    logic        [31:0]             data_tx            [(N_PE_X - 1):0][(N_PE_Y - 1):0][(HERMES_NPORT - 2):0];

    /* BrLite signals */
    logic        [(BR_NPORT - 2):0] req_rx             [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        [(BR_NPORT - 2):0] ack_rx             [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    br_data_t    [(BR_NPORT - 2):0] flit_rx            [(N_PE_X - 1):0][(N_PE_Y - 1):0];

    logic        [(BR_NPORT - 2):0] req_tx             [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    logic        [(BR_NPORT - 2):0] ack_tx             [(N_PE_X - 1):0][(N_PE_Y - 1):0];
    br_data_t    [(BR_NPORT - 2):0] flit_tx            [(N_PE_X - 1):0][(N_PE_Y - 1):0];

////////////////////////////////////////////////////////////////////////////////
// MA Injector
////////////////////////////////////////////////////////////////////////////////

    logic        ma_inj_tx;
    logic        ma_inj_eop_tx;
    logic        ma_inj_credit_tx;
    logic [31:0] ma_inj_data_tx;

    logic        ma_inj_rx;
    logic        ma_inj_eop_rx;
    logic        ma_inj_credit_rx;
    logic [31:0] ma_inj_data_rx;

    TaskInjector #(
        .INJECTOR_ADDRESS ({1'b1, PORT_MA_INJ[1:0], 13'b0, ADDR_MA_INJ}),
        .FLIT_SIZE        (32                                          ),
        .MAX_PAYLOAD_SIZE (32                                          ),
        .INJECT_MAPPER    (1                                           )
    )
    MAInjector (
        .clk_i           (clk_i           ),
        .rst_ni          (rst_ni          ),
        .src_eoa_i       ('0              ),
        .src_rx_i        (ma_src_rx_i     ),
        .src_credit_o    (ma_src_credit_o ),
        .src_data_i      (ma_src_data_i   ),
        .mapper_address_i(mapper_address_i),
        .noc_tx_o        (ma_inj_tx       ),
        .noc_eop_o       (ma_inj_eop_tx   ),
        .noc_credit_i    (ma_inj_credit_tx),
        .noc_data_o      (ma_inj_data_tx  ),
        .noc_rx_i        (ma_inj_rx       ),
        .noc_eop_i       (ma_inj_eop_rx   ),
        .noc_credit_o    (ma_inj_credit_rx),
        .noc_data_i      (ma_inj_data_rx  )
    );

    always_comb begin
        localparam logic [($clog2(N_PE_X)-1):0] x = ADDR_MA_INJ[($clog2(N_PE_X) + 7):8];
        localparam logic [($clog2(N_PE_Y)-1):0] y = ADDR_MA_INJ[($clog2(N_PE_Y) - 1):0];
        ma_inj_rx        = tx       [x][y][2'(PORT_MA_INJ)];
        ma_inj_eop_rx    = eop_tx   [x][y][2'(PORT_MA_INJ)];
        ma_inj_credit_tx = credit_rx[x][y][2'(PORT_MA_INJ)];
        ma_inj_data_rx   = data_tx  [x][y][2'(PORT_MA_INJ)];
    end

////////////////////////////////////////////////////////////////////////////////
// App Injector
////////////////////////////////////////////////////////////////////////////////

    logic        app_inj_tx;
    logic        app_inj_eop_tx;
    logic        app_inj_credit_tx;
    logic [31:0] app_inj_data_tx;

    logic        app_inj_rx;
    logic        app_inj_eop_rx;
    logic        app_inj_credit_rx;
    logic [31:0] app_inj_data_rx;

    TaskInjector #(
        .INJECTOR_ADDRESS ({1'b1, PORT_APP_INJ[1:0], 13'b0, ADDR_APP_INJ}),
        .FLIT_SIZE        (32                                            ),
        .MAX_PAYLOAD_SIZE (32                                            ),
        .INJECT_MAPPER    (0                                             )
    )
    AppInjector (
        .clk_i           (clk_i            ),
        .rst_ni          (rst_ni           ),
        .src_eoa_i       (app_src_eoa_i    ),
        .src_rx_i        (app_src_rx_i     ),
        .src_credit_o    (app_src_credit_o ),
        .src_data_i      (app_src_data_i   ),
        .mapper_address_i(mapper_address_i ),
        .noc_tx_o        (app_inj_tx       ),
        .noc_eop_o       (app_inj_eop_tx   ),
        .noc_credit_i    (app_inj_credit_tx),
        .noc_data_o      (app_inj_data_tx  ),
        .noc_rx_i        (app_inj_rx       ),
        .noc_eop_i       (app_inj_eop_rx   ),
        .noc_credit_o    (app_inj_credit_rx),
        .noc_data_i      (app_inj_data_rx  )
    );

    always_comb begin
        localparam logic [($clog2(N_PE_X)-1):0] x = ADDR_APP_INJ[($clog2(N_PE_X) + 7):8];
        localparam logic [($clog2(N_PE_Y)-1):0] y = ADDR_APP_INJ[($clog2(N_PE_Y) - 1):0];
        app_inj_rx        = tx       [x][y][2'(PORT_APP_INJ)] && release_peripheral[x][y];
        app_inj_eop_rx    = eop_tx   [x][y][2'(PORT_APP_INJ)] && release_peripheral[x][y];
        app_inj_credit_tx = credit_rx[x][y][2'(PORT_APP_INJ)] && release_peripheral[x][y];
        app_inj_data_rx   = data_tx  [x][y][2'(PORT_APP_INJ)];
    end

////////////////////////////////////////////////////////////////////////////////
// Add new peripherals here
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// Many-core generation
////////////////////////////////////////////////////////////////////////////////

    generate
        for (genvar x = 0; x < N_PE_X; x++) begin : gen_x_pe
            for (genvar y = 0; y < N_PE_Y; y++) begin : gen_y_pe
                localparam logic [15:0] address  = {x[7:0], y[7:0]};

                PhiversPE #(
                    .ADDRESS       (address      ),
                    .N_PE_X        (N_PE_X       ),
                    .N_PE_Y        (N_PE_Y       ),
                    .TASKS_PER_PE  (TASKS_PER_PE ),
                    .IMEM_PAGE_SZ  (IMEM_PAGE_SZ ),
                    .DMEM_PAGE_SZ  (DMEM_PAGE_SZ ),
                    .RS5_DEBUG     (RS5_DEBUG    ),
                    .Environment   (Environment  ),
                    .UART_DEBUG    (UART_DEBUG   ),
                    .SCHED_DEBUG   (SCHED_DEBUG  ),
                    .PIPE_DEBUG    (PIPE_DEBUG   ),
                    .TRAFFIC_DEBUG (TRAFFIC_DEBUG),
                    .DMNI_DEBUG    (DMNI_DEBUG   )
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
                    .noc_eop_i            (eop_rx[x][y]            ),
                    .noc_credit_o         (credit_rx[x][y]         ),
                    .noc_data_i           (data_rx[x][y]           ),
                    .noc_tx_o             (tx[x][y]                ),
                    .noc_eop_o            (eop_tx[x][y]            ),
                    .noc_credit_i         (credit_tx[x][y]         ),
                    .noc_data_o           (data_tx[x][y]           ),
                    .brlite_req_i         (req_rx[x][y]            ),
                    .brlite_ack_o         (ack_rx[x][y]            ),
                    .brlite_flit_i        (flit_rx[x][y]           ),
                    .brlite_req_o         (req_tx[x][y]            ),
                    .brlite_ack_i         (ack_tx[x][y]            ),
                    .brlite_flit_o        (flit_tx[x][y]           )
                );
            end
        end
    endgenerate

////////////////////////////////////////////////////////////////////////////////
// NoC connection
////////////////////////////////////////////////////////////////////////////////

    generate
        for (genvar x = 0; x < N_PE_X; x++) begin : gen_link_x
            for (genvar y = 0; y < N_PE_Y; y++) begin : gen_link_y
                localparam logic [15:0] address  = {x[7:0], y[7:0]};
                localparam IDX = (y * N_PE_X + x) * HERMES_NPORT;
                if (x != 0) begin : gen_link_west
                    PhiversLink #(
                        .ADDRESS (address                    ),
                        .PORT    ("W"                        ),
                        .LINK_CFG(LINK_CFG[IDX + HERMES_WEST])
                    ) link (
                        .clk_i      (clk_i                               ),
                        .rst_ni     (rst_ni                              ),
                        .tx_i       (tx       [x    ][y][2'(HERMES_WEST)]),
                        .cr_tx_o    (credit_tx[x    ][y][2'(HERMES_WEST)]),
                        .eop_tx_i   (eop_tx   [x    ][y][2'(HERMES_WEST)]),
                        .data_tx_i  (data_tx  [x    ][y][2'(HERMES_WEST)]),
                        .rx_o       (rx       [x - 1][y][2'(HERMES_EAST)]),
                        .cr_rx_i    (credit_rx[x - 1][y][2'(HERMES_EAST)]),
                        .eop_rx_o   (eop_rx   [x - 1][y][2'(HERMES_EAST)]),
                        .data_rx_o  (data_rx  [x - 1][y][2'(HERMES_EAST)])
                    );
                end

                if (x != N_PE_X - 1) begin : gen_link_east
                    PhiversLink #(
                        .ADDRESS (address                    ),
                        .PORT    ("E"                        ),
                        .LINK_CFG(LINK_CFG[IDX + HERMES_EAST])
                    ) link (
                        .clk_i      (clk_i                               ),
                        .rst_ni     (rst_ni                              ),
                        .tx_i       (tx       [x    ][y][2'(HERMES_EAST)]),
                        .cr_tx_o    (credit_tx[x    ][y][2'(HERMES_EAST)]),
                        .eop_tx_i   (eop_tx   [x    ][y][2'(HERMES_EAST)]),
                        .data_tx_i  (data_tx  [x    ][y][2'(HERMES_EAST)]),
                        .rx_o       (rx       [x + 1][y][2'(HERMES_WEST)]),
                        .cr_rx_i    (credit_rx[x + 1][y][2'(HERMES_WEST)]),
                        .eop_rx_o   (eop_rx   [x + 1][y][2'(HERMES_WEST)]),
                        .data_rx_o  (data_rx  [x + 1][y][2'(HERMES_WEST)])
                    );
                end

                if (y != 0) begin : gen_link_south
                    PhiversLink #(
                        .ADDRESS (address                     ),
                        .PORT    ("S"                         ),
                        .LINK_CFG(LINK_CFG[IDX + HERMES_SOUTH])
                    ) link (
                        .clk_i      (clk_i                                ),
                        .rst_ni     (rst_ni                               ),
                        .tx_i       (tx       [x][y    ][2'(HERMES_SOUTH)]),
                        .cr_tx_o    (credit_tx[x][y    ][2'(HERMES_SOUTH)]),
                        .eop_tx_i   (eop_tx   [x][y    ][2'(HERMES_SOUTH)]),
                        .data_tx_i  (data_tx  [x][y    ][2'(HERMES_SOUTH)]),
                        .rx_o       (rx       [x][y - 1][2'(HERMES_NORTH)]),
                        .cr_rx_i    (credit_rx[x][y - 1][2'(HERMES_NORTH)]),
                        .eop_rx_o   (eop_rx   [x][y - 1][2'(HERMES_NORTH)]),
                        .data_rx_o  (data_rx  [x][y - 1][2'(HERMES_NORTH)])
                    );
                end

                if (y != N_PE_Y - 1) begin : gen_link_north
                    PhiversLink #(
                        .ADDRESS (address                     ),
                        .PORT    ("N"                         ),
                        .LINK_CFG(LINK_CFG[IDX + HERMES_NORTH])
                    ) link (
                        .clk_i      (clk_i                                ),
                        .rst_ni     (rst_ni                               ),
                        .tx_i       (tx       [x][y    ][2'(HERMES_NORTH)]),
                        .cr_tx_o    (credit_tx[x][y    ][2'(HERMES_NORTH)]),
                        .eop_tx_i   (eop_tx   [x][y    ][2'(HERMES_NORTH)]),
                        .data_tx_i  (data_tx  [x][y    ][2'(HERMES_NORTH)]),
                        .rx_o       (rx       [x][y + 1][2'(HERMES_SOUTH)]),
                        .cr_rx_i    (credit_rx[x][y + 1][2'(HERMES_SOUTH)]),
                        .eop_rx_o   (eop_rx   [x][y + 1][2'(HERMES_SOUTH)]),
                        .data_rx_o  (data_rx  [x][y + 1][2'(HERMES_SOUTH)])
                    );
                end
            end
        end
    endgenerate

////////////////////////////////////////////////////////////////////////////////
// NoC border grounding and peripheral connection
////////////////////////////////////////////////////////////////////////////////

    always_comb begin
        /* MA Injector address */
        localparam logic [($clog2(N_PE_X)-1):0] MA_INJ_X = ADDR_MA_INJ[($clog2(N_PE_X) + 7):8];
        localparam logic [($clog2(N_PE_Y)-1):0] MA_INJ_Y = ADDR_MA_INJ[($clog2(N_PE_Y) - 1):0];

        /* App Injector address */
        localparam logic [($clog2(N_PE_X)-1):0] APP_INJ_X = ADDR_APP_INJ[($clog2(N_PE_X) + 7):8];
        localparam logic [($clog2(N_PE_Y)-1):0] APP_INJ_Y = ADDR_APP_INJ[($clog2(N_PE_Y) - 1):0];
        
        /* North and south ground */
        for (int x = 0; x < N_PE_X; x++) begin
            rx       [x][N_PE_Y - 1][2'(HERMES_NORTH)] = '0;
            eop_rx   [x][N_PE_Y - 1][2'(HERMES_NORTH)] = '0;
            credit_tx[x][N_PE_Y - 1][2'(HERMES_NORTH)] = '1;
            data_rx  [x][N_PE_Y - 1][2'(HERMES_NORTH)] = '0;

            rx       [x][0         ][2'(HERMES_SOUTH)] = '0;
            eop_rx   [x][0         ][2'(HERMES_SOUTH)] = '0;
            credit_tx[x][0         ][2'(HERMES_SOUTH)] = '1;
            data_rx  [x][0         ][2'(HERMES_SOUTH)] = '0;
        end

        /* East and west ground */
        for (int y = 0; y < N_PE_Y; y++) begin
            rx       [N_PE_X - 1][y][2'(HERMES_EAST)]  = '0;
            eop_rx   [N_PE_X - 1][y][2'(HERMES_EAST)]  = '0;
            credit_tx[N_PE_X - 1][y][2'(HERMES_EAST)]  = '1;
            data_rx  [N_PE_X - 1][y][2'(HERMES_EAST)]  = '0;

            rx       [0         ][y][2'(HERMES_WEST)]  = '0;
            eop_rx   [0         ][y][2'(HERMES_WEST)]  = '0;
            credit_tx[0         ][y][2'(HERMES_WEST)]  = '1;
            data_rx  [0         ][y][2'(HERMES_WEST)]  = '0;
        end

        /* MA Injector connection */
        rx       [MA_INJ_X][MA_INJ_Y][2'(PORT_MA_INJ)] = ma_inj_tx;
        eop_rx   [MA_INJ_X][MA_INJ_Y][2'(PORT_MA_INJ)] = ma_inj_eop_tx;
        credit_tx[MA_INJ_X][MA_INJ_Y][2'(PORT_MA_INJ)] = ma_inj_credit_rx;
        data_rx  [MA_INJ_X][MA_INJ_Y][2'(PORT_MA_INJ)] = ma_inj_data_tx;

        /* App Injector connection */
        rx       [APP_INJ_X][APP_INJ_Y][2'(PORT_APP_INJ)] = app_inj_tx        && release_peripheral[APP_INJ_X][APP_INJ_Y];
        eop_rx   [APP_INJ_X][APP_INJ_Y][2'(PORT_APP_INJ)] = app_inj_eop_tx    && release_peripheral[APP_INJ_X][APP_INJ_Y];
        credit_tx[APP_INJ_X][APP_INJ_Y][2'(PORT_APP_INJ)] = app_inj_credit_rx && release_peripheral[APP_INJ_X][APP_INJ_Y];
        data_rx  [APP_INJ_X][APP_INJ_Y][2'(PORT_APP_INJ)] = app_inj_data_tx;

        /* Insert the IO wiring for your component here if it connected to a port */
    end

////////////////////////////////////////////////////////////////////////////////
// BrLite connection
////////////////////////////////////////////////////////////////////////////////

    always_comb begin
        for (int x = 0; x < N_PE_X; x++) begin
            for (int y = 0; y < N_PE_Y; y++) begin
                req_rx [x][y][2'(BR_EAST)]  = (x != N_PE_X - 1) ? req_tx [x + 1][y][2'(BR_WEST)]  : '0;
                ack_tx [x][y][2'(BR_EAST)]  = (x != N_PE_X - 1) ? ack_rx [x + 1][y][2'(BR_WEST)]  : '1;
                flit_rx[x][y][2'(BR_EAST)]  = (x != N_PE_X - 1) ? flit_tx[x + 1][y][2'(BR_WEST)]  : '0;

                req_rx [x][y][2'(BR_WEST)]  = (x != 0)          ? req_tx [x - 1][y][2'(BR_EAST)]  : '0;
                ack_tx [x][y][2'(BR_WEST)]  = (x != 0)          ? ack_rx [x - 1][y][2'(BR_EAST)]  : '1;
                flit_rx[x][y][2'(BR_WEST)]  = (x != 0)          ? flit_tx[x - 1][y][2'(BR_EAST)]  : '0;

                req_rx [x][y][2'(BR_NORTH)] = (y != N_PE_Y - 1) ? req_tx [x][y + 1][2'(BR_SOUTH)] : '0;
                ack_tx [x][y][2'(BR_NORTH)] = (y != N_PE_Y - 1) ? ack_rx [x][y + 1][2'(BR_SOUTH)] : '1;
                flit_rx[x][y][2'(BR_NORTH)] = (y != N_PE_Y - 1) ? flit_tx[x][y + 1][2'(BR_SOUTH)] : '0;

                req_rx [x][y][2'(BR_SOUTH)] = (y != 0)          ? req_tx [x][y - 1][2'(BR_NORTH)] : '0;
                ack_tx [x][y][2'(BR_SOUTH)] = (y != 0)          ? ack_rx [x][y - 1][2'(BR_NORTH)] : '1;
                flit_rx[x][y][2'(BR_SOUTH)] = (y != 0)          ? flit_tx[x][y - 1][2'(BR_NORTH)] : '0;
            end
        end
    end

endmodule
