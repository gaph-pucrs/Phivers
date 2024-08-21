module PhiversLink (
    // input  logic clk_i,
    // input  logic rst_ni,

    input  logic        tx_i,
    output logic        cr_tx_o,
    input  logic        eop_tx_i,
    input  logic [31:0] data_tx_i,

    output logic        rx_o,
    input  logic        cr_rx_i,
    output logic        eop_rx_o,
    output logic [31:0] data_rx_o
);

    assign rx_o      = tx_i;
    assign cr_tx_o   = cr_rx_i;
    assign eop_rx_o  = eop_tx_i;
    assign data_rx_o = data_tx_i;

endmodule
