/**
 * Phivers
 * @file PhiversOszFilter.sv
 *
 * @brief OSZ zone wrapper: one direction of one external NoC link of a PE
 *
 * @details Sits between a link and the router (or the router and a link).
 * The port mode is taken at a packet's header and kept until its end-of-packet,
 * so a mode change never cuts a packet in two.
 *
 *   OPEN     every packet passes (combinational, no added latency)
 *   BLOCKED  every packet is dropped whole: its flits are accepted and discarded
 *   ACCESS   the zone's access point (entrance). The header is held and the
 *            packet is accepted or dropped whole:
 *              TASK_ALLOCATION                      -> accepted (only injectors send it)
 *              DATA_AV, MESSAGE_REQUEST, _DELIVERY  -> flit 1 (the source) must be an
 *                                                      injector (bit 31) or the allowed
 *                                                      source (the mapper PE)
 *              anything else                        -> dropped
 *            This is a stand-in policy; the shared-key check replaces it.
 */

module PhiversOszFilter
#(
    /* Identify the filter to the simulation-only monitors bound from PhiversTB */
    /* verilator lint_off UNUSEDPARAM */
    parameter logic [15:0] ADDRESS = 16'h0000,
    parameter string       PORT    = "E",
    parameter string       DIR     = "RX"
    /* verilator lint_on UNUSEDPARAM */
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic [1:0]  mode_i,         /* OSZ_OPEN, OSZ_BLOCKED, OSZ_ACCESS */
    input  logic        src_valid_i,
    input  logic [15:0] src_i,

    /* Upstream (where flits come from) */
    input  logic        rx_i,
    input  logic        eop_i,
    input  logic [31:0] data_i,
    output logic        credit_o,

    /* Downstream (where flits go to) */
    output logic        rx_o,
    output logic        eop_o,
    output logic [31:0] data_o,
    input  logic        credit_i
);

    localparam logic [1:0] OSZ_OPEN    = 2'd0;
    localparam logic [1:0] OSZ_BLOCKED = 2'd1;
    localparam logic [1:0] OSZ_ACCESS  = 2'd2;

    localparam logic [7:0] DATA_AV          = 8'h40;
    localparam logic [7:0] MESSAGE_REQUEST  = 8'h41;
    localparam logic [7:0] TASK_ALLOCATION  = 8'h42;
    localparam logic [7:0] MESSAGE_DELIVERY = 8'h43;

    typedef enum logic [2:0] {
        F_IDLE,     /* waiting for a header */
        F_PASS,     /* forwarding the rest of an accepted packet */
        F_DROP,     /* discarding the rest of a dropped packet */
        F_HOLD,     /* access point: header held, waiting for flit 1 */
        F_HEADER    /* access point: accepted, forwarding the held header */
    } filt_t;

    filt_t state;
    filt_t next_state;

    logic [31:0] header;
    logic        header_eop;   /* the held header was a single-flit packet */

    /**
     * Decision on the header flit. It must not depend on eop_i: credit_o is
     * derived from it, and an injector derives its eop from that credit.
     */
    typedef enum logic [1:0] {D_PASS, D_DROP, D_HOLD} dec_t;
    dec_t decision;

    logic [7:0] service;
    assign service = data_i[23:16];

    always_comb begin
        case (mode_i)
            OSZ_BLOCKED:
                decision = D_DROP;
            OSZ_ACCESS: begin
                if (service == TASK_ALLOCATION)
                    decision = D_PASS;
                else if (service inside {DATA_AV, MESSAGE_REQUEST, MESSAGE_DELIVERY})
                    decision = D_HOLD;
                else
                    decision = D_DROP;
            end
            OSZ_OPEN:
                decision = D_PASS;
            default:
                decision = D_PASS;
        endcase
    end

    /* Access point: flit 1 of a handshake packet is its source */
    logic source_ok;
    assign source_ok = data_i[31] || (src_valid_i && data_i[15:0] == src_i);

    always_comb begin
        rx_o     = 1'b0;
        eop_o    = eop_i;
        data_o   = data_i;
        credit_o = 1'b0;

        case (state)
            F_IDLE: begin
                if (rx_i) begin
                    case (decision)
                        D_PASS: begin
                            rx_o     = 1'b1;
                            credit_o = credit_i;
                        end
                        default:
                            credit_o = 1'b1;    /* dropped, or taken into the hold register */
                    endcase
                end
            end
            F_PASS: begin
                rx_o     = rx_i;
                credit_o = credit_i;
            end
            F_DROP:
                credit_o = 1'b1;
            F_HOLD:
                credit_o = !header_eop && rx_i && !source_ok;  /* rejected: flit 1 is the first one discarded */
            F_HEADER: begin
                rx_o   = 1'b1;                  /* flit 1 waits upstream until the header is out */
                data_o = header;
                eop_o  = 1'b0;
            end
            default: ;
        endcase
    end

    always_comb begin
        next_state = state;
        case (state)
            F_IDLE: begin
                if (rx_i) begin
                    case (decision)
                        D_PASS:  if (credit_i) next_state = eop_i ? F_IDLE : F_PASS;
                        D_DROP:  next_state = eop_i ? F_IDLE : F_DROP;
                        D_HOLD:  next_state = F_HOLD;
                        default: ;
                    endcase
                end
            end
            F_PASS:
                if (rx_i && credit_i && eop_i) next_state = F_IDLE;
            F_DROP:
                if (rx_i && eop_i) next_state = F_IDLE;
            F_HOLD:
                if (header_eop)
                    next_state = F_IDLE;    /* single flit: no source to check, dropped */
                else if (rx_i)
                    next_state = source_ok ? F_HEADER : (eop_i ? F_IDLE : F_DROP);
            F_HEADER:
                if (credit_i) next_state = F_PASS;
            default:
                next_state = F_IDLE;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state      <= F_IDLE;
            header     <= '0;
            header_eop <= 1'b0;
        end
        else begin
            state <= next_state;
            if (state == F_IDLE && rx_i && decision == D_HOLD) begin
                header     <= data_i;
                header_eop <= eop_i;
            end
        end
    end

    /**
     * Decision status, one cycle each, for the simulation-only monitor
     * (sim/OszFilterTrace.sv, bound from PhiversTB under `ifdef OSZ_TRACE).
     * Plain logic, unused by the RTL itself.
     */
    /* verilator lint_off UNUSEDSIGNAL */
    logic ev_drop;            /* a header is dropped at once (blocked port, or service refused at the access point) */
    logic ev_drop_blocked;    /* ... because the port is blocked */
    logic ev_hold;            /* the access point takes a header into the hold register */
    logic ev_accept;          /* the access point lets a packet in */
    logic ev_refuse_src;      /* the access point refuses a held packet: flit 1 is not an accepted source */
    logic ev_refuse_single;   /* the access point drops a held single-flit packet */
    /* verilator lint_on UNUSEDSIGNAL */

    assign ev_drop          = (state == F_IDLE) && rx_i && (decision == D_DROP);
    assign ev_drop_blocked  = ev_drop && (mode_i == OSZ_BLOCKED);
    assign ev_hold          = (state == F_IDLE) && rx_i && (decision == D_HOLD);
    assign ev_accept        = ((state == F_HOLD) && !header_eop && rx_i && source_ok)
                           || ((state == F_IDLE) && rx_i && credit_i && (decision == D_PASS) && (mode_i == OSZ_ACCESS));
    assign ev_refuse_src    = (state == F_HOLD) && !header_eop && rx_i && !source_ok;
    assign ev_refuse_single = (state == F_HOLD) && header_eop;

endmodule
