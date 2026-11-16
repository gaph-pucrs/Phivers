`include "../Hermes/rtl/HermesPkg.sv"
`include "../BrLite/rtl/BrLitePkg.sv"

/**
 * Router and BrLite traffic of one PE, bound from the testbench into every
 * PhiversPE: one TrafficRouter and one TrafficBroadcast per port.
 */
module TrafficDebug
    import HermesPkg::*;
    import BrLitePkg::*;
#(
    parameter logic [15:0] ADDRESS = 16'h0000
)
(
    input logic                       clk_i,
    input logic                       rst_ni,

    /* Router inputs (the local port is the DMNI output) */
    input logic                       noc_rx_i         [(HERMES_NPORT - 1):0],
    input logic                       noc_eop_rcv_i    [(HERMES_NPORT - 1):0],
    input logic                       noc_credit_rcv_i [(HERMES_NPORT - 1):0],
    input logic     [31:0]            noc_data_rcv_i   [(HERMES_NPORT - 1):0],

    /* BrLite router inputs */
    input logic     [(BR_NPORT - 1):0] brlite_req_rcv_i,
    input logic     [(BR_NPORT - 1):0] brlite_ack_rcv_i,
    input br_data_t [(BR_NPORT - 1):0] brlite_flit_rcv_i,

    input logic     [63:0]            tick_cntr_i
);

    for (genvar p = 0; p < HERMES_NPORT; p++) begin : gen_traffic_router
        TrafficRouter #(
            .FLIT_SIZE(32                          ),
            .ADDRESS  (ADDRESS                     ),
            .PORT     (hermes_port_t'(p)           ),
            .FILE_NAME("./debug/traffic_router.txt")
        )
        traffic_router (
            .clk_i      (clk_i              ),
            .rst_ni     (rst_ni             ),
            .rx_i       (noc_rx_i[p]        ),
            .eop_i      (noc_eop_rcv_i[p]   ),
            .credit_i   (noc_credit_rcv_i[p]),
            .data_i     (noc_data_rcv_i[p]  ),
            .tick_cntr_i(tick_cntr_i        )
        );

        TrafficBroadcast #(
            .ADDRESS  (ADDRESS                     ),
            .PORT     (br_port_t'(p)               ),
            .FILE_NAME("./debug/traffic_router.txt")
        )
        traffic_broadcast (
            .clk_i      (clk_i               ),
            .rst_ni     (rst_ni              ),
            .rx_i       (brlite_req_rcv_i[p] ),
            .ack_rx_i   (brlite_ack_rcv_i[p] ),
            .data_i     (brlite_flit_rcv_i[p]),
            .tick_cntr_i(tick_cntr_i         )
        );
    end

endmodule
