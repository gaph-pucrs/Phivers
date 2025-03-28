module PhiversLink
#(
    parameter logic [15:0] ADDRESS  = 16'b0,
    parameter string       PORT     = "",
    parameter string       LINK_CFG = ""
)
(
    /* No always used */
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic        clk_i,
    input  logic        rst_ni,
    /* verilator lint_on UNUSEDSIGNAL */

    input  logic        tx_i,
    output logic        cr_tx_o,
    input  logic        eop_tx_i,
    input  logic [31:0] data_tx_i,

    output logic        rx_o,
    input  logic        cr_rx_i,
    output logic        eop_rx_o,
    output logic [31:0] data_rx_o
);

    generate
        if (LINK_CFG == "rs") begin : gen_ht_rs
            RedSignal #(
                .ADDRESS(ADDRESS  ),
                .PORT   (PORT     )
            ) rs (
                .clk_i    (clk_i    ),
                .rst_ni   (rst_ni   ),
                .tx_i     (tx_i     ),
                .cr_tx_o  (cr_tx_o  ),
                .eop_tx_i (eop_tx_i ),
                .data_tx_i(data_tx_i),
                .rx_o     (rx_o     ),
                .cr_rx_i  (cr_rx_i  )
            );
            assign eop_rx_o  = eop_tx_i;
            assign data_rx_o = data_tx_i;
        end
        else begin : gen_no_ht
            assign rx_o      = tx_i;
            assign cr_tx_o   = cr_rx_i;
            assign eop_rx_o  = eop_tx_i;
            assign data_rx_o = data_tx_i;
        end
    endgenerate

endmodule
