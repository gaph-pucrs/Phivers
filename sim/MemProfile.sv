/**
 * Phivers
 * @file MemProfile.sv
 *
 * @brief Memory occupancy profiler for simulation.
 *
 * @detailed
 * Records which BLOCK_SZ-sized blocks of a RAM_mem instance are ever touched,
 * and dumps a per-page summary when the simulation ends. Unlike RAM_DEBUG,
 * which logs every access, this keeps a single bit per block, so it can be
 * left enabled for a full run.
 *
 * Each page is reported with:
 *   bytes_touched  Blocks touched * BLOCK_SZ: the resident footprint.
 *   lo_addr        Start of the lowest touched block, page-relative.
 *   hi_addr        End of the highest touched block, page-relative.
 *   low_run_end    End of the contiguous touched run starting at the page
 *                  base. For a task data page this is the .data + .bss + heap
 *                  high-water mark.
 *   high_run_start Start of the contiguous touched run ending at the page top.
 *                  For a task data page this is the stack low-water mark,
 *                  since the stack starts at the top of the page and grows
 *                  down (MAestro/src/task_control.c).
 */

module MemProfile
#(
    parameter int          MEM_SZ   = 65536,
    parameter int          PAGE_SZ  = 32768,
    parameter int          BLOCK_SZ = 4096,
    parameter logic [15:0] ADDRESS  = 16'h0000,
    parameter string       MEM_NAME = "D",
    parameter string       LOG_PATH = "./debug/ram"
)
(
    input logic        clk,

    input logic        enA_i,
    input logic        enB_i,

    /* Only the block-index bits of the addresses are profiled. */
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [29:0] addrA_i,
    input logic [29:0] addrB_i
    /* verilator lint_on UNUSEDSIGNAL */
);

    localparam int ADDR_BITS   = $clog2(MEM_SZ);
    localparam int BLOCK_BITS  = $clog2(BLOCK_SZ);
    localparam int INDEX_BITS  = ADDR_BITS - BLOCK_BITS;
    /* Sized to the address slice, so an index can never fall out of range. */
    localparam int BLOCKS      = 1 << INDEX_BITS;
    localparam int PAGES       = MEM_SZ / PAGE_SZ;
    localparam int PAGE_BLOCKS = PAGE_SZ / BLOCK_SZ;

    logic touched [BLOCKS];

    initial begin
        for (int i = 0; i < BLOCKS; i++)
            touched[i] = 1'b0;
    end

    always_ff @(posedge clk) begin
        if (enA_i)
            touched[addrA_i[(ADDR_BITS - 1):BLOCK_BITS]] <= 1'b1;

        if (enB_i)
            touched[addrB_i[(ADDR_BITS - 1):BLOCK_BITS]] <= 1'b1;
    end

    final begin
        int    fd;
        int    base;
        int    count;
        int    lo;
        int    hi;
        int    low_run;
        int    high_run;
        string file;

        file = $sformatf(
            "%s/%0dx%0d_%s_profile.csv", 
            LOG_PATH, 
            ADDRESS[15:8], 
            ADDRESS[7:0], 
            MEM_NAME
        );

        fd = $fopen(file, "w");
        if (fd == '0) begin
            $display("[MemProfile %0dx%0d_%s] Could not open %s", 
                ADDRESS[15:8], ADDRESS[7:0], MEM_NAME, file);
        end
        else begin
            $fwrite(fd, "page,page_sz,block_sz,blocks_touched,bytes_touched,");
            $fwrite(fd, "lo_addr,hi_addr,low_run_end,high_run_start\n");

            for (int p = 0; p < PAGES; p++) begin
                base     = p * PAGE_BLOCKS;
                count    = 0;
                lo       = -1;
                hi       = -1;
                low_run  = 0;
                high_run = PAGE_BLOCKS;

                for (int b = 0; b < PAGE_BLOCKS; b++) begin
                    if (touched[base + b]) begin
                        count++;
                        if (lo == -1)
                            lo = b;
                        hi = b;
                    end
                end

                /* Contiguous run growing up from the page base. */
                while (low_run < PAGE_BLOCKS && touched[base + low_run])
                    low_run++;

                /* Contiguous run growing down from the page top. */
                while (high_run > 0 && touched[base + high_run - 1])
                    high_run--;

                $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                    p,
                    PAGE_SZ,
                    BLOCK_SZ,
                    count,
                    count * BLOCK_SZ,
                    (lo == -1) ? 0 :  lo      * BLOCK_SZ,
                    (hi == -1) ? 0 : (hi + 1) * BLOCK_SZ,
                    low_run  * BLOCK_SZ,
                    high_run * BLOCK_SZ
                );
            end

            $fclose(fd);
        end
    end

endmodule
