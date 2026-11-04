/**
 * Phivers
 * @file OszFilterTrace.sv
 *
 * @brief Monitor of one OSZ zone wrapper filter (simulation only)
 *
 * @details
 * Attached to every PhiversOszFilter with `bind` from PhiversTB under
 * `ifdef OSZ_TRACE`; the RTL never instantiates it. It turns the filter's
 * decision status (ev_*) into lines of debug/osz_trace.txt, read by
 * tools/meshviz, and prints the console line regression/osz_check.py counts:
 *
 *   <cycle> <x> <y> HOLD   port=<P> dir=<RX|TX> hdr=<header>
 *   <cycle> <x> <y> ACCEPT port=<P> dir=<RX|TX> hdr=<header> src=<source|->
 *   <cycle> <x> <y> DROP   port=<P> dir=<RX|TX> reason=<blocked|service|source|single>
 *                          hdr=<header> src=<flit 1> ids=<flit 2> flits=<n>
 *
 * A DROP line is written when the dropped packet ends, with the cycle of its
 * header; hdr/src/ids are the packet's first three flits, the identity key
 * meshviz shares with debug/sr_trace.txt. The monitor counts cycles from
 * reset, which equals the PE's mtime.
 */

module OszFilterTrace
#(
    parameter logic [15:0] ADDRESS   = 16'h0000,
    parameter string       PORT      = "E",
    parameter string       DIR       = "RX",
    parameter string       FILE_NAME = "./debug/osz_trace.txt"
)
(
    input logic        clk_i,
    input logic        rst_ni,

    /* The filter's upstream handshake: flits arriving at the filter */
    input logic        rx_i,
    input logic        eop_i,
    input logic        credit_i,
    input logic [31:0] data_i,

    input logic [31:0] header_i,            /* the access point's hold register */

    input logic        ev_drop_i,
    input logic        ev_drop_blocked_i,
    input logic        ev_hold_i,
    input logic        ev_accept_i,
    input logic        ev_refuse_src_i,
    input logic        ev_refuse_single_i
);

    logic [31:0] cycle;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            cycle <= '0;
        else
            cycle <= cycle + 1'b1;
    end

    int fd;

    function automatic void write_line(string line);
        /* verilator lint_off BLKSEQ */
        fd = $fopen(FILE_NAME, "a");
        /* verilator lint_on BLKSEQ */
        if (fd == 0) begin
            $display("[OszFilterTrace] Could not open log file %s", FILE_NAME);
            $finish();
        end
        $fwrite(fd, "%s\n", line);
        $fflush(fd);
        $fclose(fd);
    endfunction

    /* Packet being dropped: captured until its end-of-packet */
    localparam logic [1:0] R_BLOCKED = 2'd0;
    localparam logic [1:0] R_SERVICE = 2'd1;
    localparam logic [1:0] R_SOURCE  = 2'd2;
    localparam logic [1:0] R_SINGLE  = 2'd3;

    function automatic string reason_name(logic [1:0] r);
        case (r)
            R_BLOCKED: return "blocked";
            R_SERVICE: return "service";
            R_SOURCE:  return "source";
            default:   return "single";
        endcase
    endfunction

    logic        dropping;
    logic        holding;
    logic [1:0]  reason;
    logic [31:0] t0;
    logic [31:0] hdr;
    logic [31:0] src;
    logic [31:0] ids;
    logic [15:0] nflits;

    function automatic void report_drop(logic [31:0] t, logic [1:0] why, logic [31:0] h, logic [31:0] s, logic [31:0] i, logic [15:0] n);
        write_line($sformatf(
            "%0d %0d %0d DROP port=%s dir=%s reason=%s hdr=%08x src=%08x ids=%08x flits=%0d",
            t, ADDRESS[15:8], ADDRESS[7:0], PORT, DIR, reason_name(why), h, s, i, n
        ));
        if (why == R_BLOCKED)
            $display(
                "[%7.3f] [OSZ] PE %0d,%0d %s %s dropped packet: target %0d,%0d service %h source %h (blocked port)",
                $time()/1_000_000.0, ADDRESS[15:8], ADDRESS[7:0], DIR, PORT, h[15:8], h[7:0], h[23:16], s
            );
        else
            $display(
                "[%7.3f] [OSZ] PE %0d,%0d %s %s dropped packet: target %0d,%0d service %h source %h (refused at access point: %s)",
                $time()/1_000_000.0, ADDRESS[15:8], ADDRESS[7:0], DIR, PORT, h[15:8], h[7:0], h[23:16], s, reason_name(why)
            );
    endfunction

    logic flit;
    assign flit = rx_i && credit_i;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            dropping <= 1'b0;
            holding  <= 1'b0;
            reason   <= R_BLOCKED;
            t0       <= '0;
            hdr      <= '0;
            src      <= '0;
            ids      <= '0;
            nflits   <= '0;
        end
        else begin
            if (ev_hold_i) begin
                holding <= 1'b1;
                write_line($sformatf(
                    "%0d %0d %0d HOLD port=%s dir=%s hdr=%08x",
                    cycle, ADDRESS[15:8], ADDRESS[7:0], PORT, DIR, data_i
                ));
            end

            if (ev_accept_i) begin
                holding <= 1'b0;
                if (holding)
                    write_line($sformatf(
                        "%0d %0d %0d ACCEPT port=%s dir=%s hdr=%08x src=%08x",
                        cycle, ADDRESS[15:8], ADDRESS[7:0], PORT, DIR, header_i, data_i
                    ));
                else
                    write_line($sformatf(
                        "%0d %0d %0d ACCEPT port=%s dir=%s hdr=%08x src=-",
                        cycle, ADDRESS[15:8], ADDRESS[7:0], PORT, DIR, data_i
                    ));
            end

            if (ev_refuse_single_i) begin
                holding <= 1'b0;
                report_drop(cycle, R_SINGLE, header_i, '0, '0, 16'd1);
            end

            if (ev_drop_i) begin
                /* The header is dropped now; the rest of the packet follows */
                if (eop_i)
                    report_drop(cycle, ev_drop_blocked_i ? R_BLOCKED : R_SERVICE, data_i, '0, '0, 16'd1);
                else begin
                    dropping <= 1'b1;
                    reason   <= ev_drop_blocked_i ? R_BLOCKED : R_SERVICE;
                    t0       <= cycle;
                    hdr      <= data_i;
                    src      <= '0;
                    ids      <= '0;
                    nflits   <= 16'd1;
                end
            end
            else if (ev_refuse_src_i) begin
                /* Flit 1 (the source) is the first one discarded; the header was held */
                holding <= 1'b0;
                if (eop_i)
                    report_drop(cycle, R_SOURCE, header_i, data_i, '0, 16'd2);
                else begin
                    dropping <= 1'b1;
                    reason   <= R_SOURCE;
                    t0       <= cycle;
                    hdr      <= header_i;
                    src      <= data_i;
                    ids      <= '0;
                    nflits   <= 16'd2;
                end
            end
            else if (dropping && flit) begin
                nflits <= nflits + 1'b1;
                if (nflits == 16'd1)
                    src <= data_i;
                else if (nflits == 16'd2)
                    ids <= data_i;

                if (eop_i) begin
                    dropping <= 1'b0;
                    report_drop(
                        t0, reason, hdr,
                        (nflits == 16'd1) ? data_i : src,
                        (nflits == 16'd2) ? data_i : ids,
                        nflits + 1'b1
                    );
                end
            end
        end
    end

endmodule
