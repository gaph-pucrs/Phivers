/**
 * Phivers
 * @file OszAttacker.sv
 *
 * @brief Simulation-only attacker for the OSZ zone closing tests
 *
 * @details Attached to an unused mesh-edge port, it injects crafted Hermes
 * packets that ignore the single-entrance routing, at fixed cycles. Each
 * packet has the handshake layout the access point inspects:
 *   flit 0  header {flags, service, target}
 *   flit 1  source
 *   flit 2  {sender, receiver}
 *   flit 3  timestamp
 *   flit 4  payload size (16 bytes)
 *   flit 5..8 payload
 * Enabled only when the testcase sets the OSZ_ATTACK parameter.
 */

module OszAttacker
#(
    parameter string       NAME   = "attacker",
    parameter int          START  = 1_000_000,     /* cycle of the first packet */
    parameter int          GAP    = 50_000,        /* cycles between packets */
    parameter int          NPKT   = 1,                 /* packets to send, at most 4 */
    parameter logic [31:0] HEADER [4] = '{default: '0},
    parameter logic [31:0] SOURCE [4] = '{default: '0}
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    output logic        tx_o,
    output logic        eop_o,
    output logic [31:0] data_o,
    input  logic        credit_i
);

    localparam int FLITS = 9;

    logic [31:0] cycle;
    logic [31:0] pkt;      /* packet being sent, NPKT when done */
    logic [31:0] flit;     /* flit index inside the packet */
    logic        sending;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            cycle <= '0;
        else
            cycle <= cycle + 1'b1;
    end

    always_comb begin
        case (flit)
            0:       data_o = HEADER[pkt];
            1:       data_o = SOURCE[pkt];
            2:       data_o = 32'hFFFF_FFFF;
            3:       data_o = cycle;
            4:       data_o = 32'd16;
            default: data_o = 32'hBAD0_0000 | flit;
        endcase
    end

    assign tx_o  = sending;
    assign eop_o = sending && (flit == FLITS - 1);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pkt     <= '0;
            flit    <= '0;
            sending <= 1'b0;
        end
        else if (!sending) begin
            if (pkt < NPKT && cycle >= START + pkt * GAP) begin
                sending <= 1'b1;
                flit    <= '0;
                $display(
                    "[%7.3f] [OSZ attack] %s sends packet %0d: target %0d,%0d service %h source %h",
                    $time()/1_000_000.0, NAME, pkt,
                    HEADER[pkt][15:8], HEADER[pkt][7:0], HEADER[pkt][23:16], SOURCE[pkt]
                );
            end
        end
        else if (credit_i) begin
            if (flit == FLITS - 1) begin
                sending <= 1'b0;
                pkt     <= pkt + 1;
            end
            else begin
                flit <= flit + 1;
            end
        end
    end

endmodule
