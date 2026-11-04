/**
 * Phivers
 * @file SRTrace.sv
 *
 * GAPH - Hardware Design Support Group (https://corfu.pucrs.br/)
 * PUCRS - Pontifical Catholic University of Rio Grande do Sul (http://pucrs.br/)
 *
 * @brief Passive monitor of every Hermes packet on one link (simulation only)
 *
 * @details
 * Attached with `bind` from PhiversTB under `ifdef SR_TRACE`, never
 * instantiated by the RTL:
 *   - on the RX side of each mesh link, before the OSZ zone wrapper
 *     (bind PhiversOszFilter), so a packet the wrapper drops is still seen
 *     arriving at the port;
 *   - on the local link in both directions (bind PhiversPE): injection by the
 *     DMNI (IN, port L) and delivery to the DMNI (DMNI).
 *
 * One line per packet. Leading source-routing headers (SR_FLAG) are counted
 * and skipped, so the fields after them are the same before and after each
 * loopback:
 *
 *   <cycle> <x> <y> <port> <dir> nsr=<n> sr0=<first flit> hdr=<first non-SR flit>
 *   src=<next flit> ids=<next flit> flits=<packet length>
 *
 * cycle is the tick of the first flit. The monitor counts cycles from reset
 * itself, which equals the PE's mtime (the RTC counts every cycle from the
 * same reset and is never written).
 *
 * Read by tools/meshviz/meshviz.py. Adapted from the SOURCE_ROUTING work.
 */

`include "../DMNI/rtl/DMNIPkg.sv"

module SRTrace
    import DMNIPkg::SR_FLAG;
#(
    parameter logic [15:0] ADDRESS   = 16'h0000,
    parameter string       PORT      = "E",          /* E W N S L */
    parameter string       DIR       = "IN",         /* IN or DMNI */
    parameter bit          ENABLE    = 1,
    parameter string       FILE_NAME = "./debug/sr_trace.txt"
)
(
    /* Unused when ENABLE = 0 (the TX side of a link) */
    /* verilator lint_off UNUSEDSIGNAL */
    input logic        clk_i,
    input logic        rst_ni,
    input logic        tx_i,
    input logic        eop_i,
    input logic        credit_i,
    input logic [31:0] data_i
    /* verilator lint_on UNUSEDSIGNAL */
);

    if (ENABLE) begin : gen_trace
        logic [31:0] cycle;
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (!rst_ni)
                cycle <= '0;
            else
                cycle <= cycle + 1'b1;
        end

        logic flit;
        assign flit = tx_i && credit_i;

        logic        in_pkt;    /* Inside a packet (header seen)    */
        logic        in_sr;     /* Still reading leading SR headers */
        logic [1:0]  post;      /* Flits seen after the SR headers  */
        logic [7:0]  nsr;
        logic [15:0] nflits;
        logic [31:0] t0;
        logic [31:0] sr0;
        logic [31:0] hdr;
        logic [31:0] src;
        logic [31:0] ids;
        logic        done;      /* The packet ended in the previous cycle */

        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (!rst_ni) begin
                in_pkt <= 1'b0;
                in_sr  <= 1'b0;
                post   <= '0;
                nsr    <= '0;
                nflits <= '0;
                t0     <= '0;
                sr0    <= '0;
                hdr    <= '0;
                src    <= '0;
                ids    <= '0;
                done   <= 1'b0;
            end
            else begin
                done <= flit && eop_i;

                if (flit) begin
                    if (!in_pkt) begin
                        /* First flit of a packet */
                        in_pkt <= !eop_i;
                        t0     <= cycle;
                        nflits <= 16'd1;
                        sr0    <= data_i;
                        src    <= '0;
                        ids    <= '0;
                        if (data_i[SR_FLAG]) begin
                            in_sr <= 1'b1;
                            nsr   <= 8'd1;
                            hdr   <= '0;
                            post  <= '0;
                        end
                        else begin
                            in_sr <= 1'b0;
                            nsr   <= '0;
                            hdr   <= data_i;
                            post  <= 2'd1;
                        end
                    end
                    else begin
                        in_pkt <= !eop_i;
                        nflits <= nflits + 1'b1;
                        if (in_sr) begin
                            if (data_i[SR_FLAG]) begin
                                nsr <= nsr + 1'b1;
                            end
                            else begin
                                in_sr <= 1'b0;
                                hdr   <= data_i;
                                post  <= 2'd1;
                            end
                        end
                        else begin
                            if (post == 2'd1)
                                src <= data_i;
                            else if (post == 2'd2)
                                ids <= data_i;

                            if (post != 2'd3)
                                post <= post + 1'b1;
                        end
                    end
                end
            end
        end

        int fd;

        /* Same open -> write -> close scheme as TrafficRouter: every monitor appends to one file */
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (!rst_ni) begin
                ;
            end
            else if (done) begin
                /* verilator lint_off BLKSEQ */
                fd = $fopen(FILE_NAME, "a");
                /* verilator lint_on BLKSEQ */
                if (fd == 0) begin
                    $display("[SRTrace] Could not open log file %s", FILE_NAME);
                    $finish();
                end

                $fwrite(
                    fd, "%0d %0d %0d %s %s nsr=%0d sr0=%08x hdr=%08x src=%08x ids=%08x flits=%0d\n",
                    t0, ADDRESS[15:8], ADDRESS[7:0], PORT, DIR, nsr, sr0, hdr, src, ids, nflits
                );

                $fflush(fd);
                $fclose(fd);
            end
        end
    end

endmodule
