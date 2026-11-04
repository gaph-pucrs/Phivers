/**
 * Phivers
 * @file OszPeTrace.sv
 *
 * @brief Monitor of one PE's OSZ state (simulation only)
 *
 * @details
 * Attached to every PhiversPE with `bind` from PhiversTB under
 * `ifdef OSZ_TRACE`; the RTL never instantiates it. It writes to
 * debug/osz_trace.txt, read by tools/meshviz:
 *
 *   <cycle> <x> <y> BLOCK  block=<DMNI_OSZ_BLOCK value>
 *       on every change of the register: blocked ports, access point, the
 *       accepted source (see DMNIPkg)
 *   <cycle> <x> <y> KERNEL ev=<name> data=<hex>
 *       on every kernel write to the OSZ debug register (MMR_DBG_OSZ,
 *       offset 0x70 of the debug area): {event[31:24], data[23:0]}
 *
 * cycle is the PE's mtime.
 */

module OszPeTrace
#(
    parameter logic [15:0] ADDRESS   = 16'h0000,
    parameter string       FILE_NAME = "./debug/osz_trace.txt"
)
(
    input logic        clk_i,
    input logic        rst_ni,
    /* Only the lower 32 bits are logged */
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [63:0] tick_i,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [31:0] osz_block_i,
    input logic        dbg_en_i,
    input logic        dbg_we_i,
    input logic [23:0] dbg_addr_i,
    input logic [31:0] dbg_data_i
);

    /* Kernel events, see MAestro/src/include/osz.h (OSZ_DBG_*) */
    function automatic string kernel_event(logic [7:0] ev);
        case (ev)
            8'd1:    return "MAPPER";          /* mapper PE learned from RELEASE_PERIPHERAL */
            8'd2:    return "TASK_HELD";       /* TASK_RELEASE held until the zone is claimed */
            8'd3:    return "TASK_RELEASED";   /* held task released */
            8'd4:    return "TASK_CLEARED";    /* a secure task's memory cleared */
            8'd5:    return "TASK_DONE";       /* OSZ_TASK_DONE broadcast sent */
            8'd6:    return "ZONE_CLEAR";      /* OSZ_ZONE_CLEAR handled on this PE */
            8'd7:    return "ZONE_CLEARED";    /* OSZ_ZONE_CLEARED broadcast sent */
            8'd8:    return "BCAST_IGNORED";   /* a zone broadcast not from the mapper */
            default: return "UNKNOWN";
        endcase
    endfunction

    localparam logic [23:0] DBG_OSZ = 24'h000070;

    int fd;

    function automatic void write_line(string line);
        /* verilator lint_off BLKSEQ */
        fd = $fopen(FILE_NAME, "a");
        /* verilator lint_on BLKSEQ */
        if (fd == 0) begin
            $display("[OszPeTrace] Could not open log file %s", FILE_NAME);
            $finish();
        end
        $fwrite(fd, "%s\n", line);
        $fflush(fd);
        $fclose(fd);
    endfunction

    logic [31:0] block_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            block_q <= '0;
        end
        else begin
            block_q <= osz_block_i;

            if (osz_block_i != block_q)
                write_line($sformatf(
                    "%0d %0d %0d BLOCK block=%08x",
                    tick_i[31:0], ADDRESS[15:8], ADDRESS[7:0], osz_block_i
                ));

            if (dbg_en_i && dbg_we_i && dbg_addr_i == DBG_OSZ)
                write_line($sformatf(
                    "%0d %0d %0d KERNEL ev=%s data=%06x",
                    tick_i[31:0], ADDRESS[15:8], ADDRESS[7:0],
                    kernel_event(dbg_data_i[31:24]), dbg_data_i[23:0]
                ));
        end
    end

endmodule
