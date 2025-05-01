`include "../BrLite/rtl/BrLitePkg.sv"
`include "../TaskInjector/rtl/TaskInjectorPkg.sv"

module TrafficBroadcast
    import BrLitePkg::*;
    import TaskInjectorPkg::*;
#(
    parameter logic [15:0] ADDRESS   = 16'h0000,
    parameter br_port_t    PORT      = BR_EAST,
    parameter string       FILE_NAME = "./debug/traffic_router.txt"
)
(
    input logic clk_i,
    input logic rst_ni,

    input logic                   rx_i,
    input logic                   ack_rx_i,

    /* verilator lint_off UNUSEDSIGNAL */
    input br_data_t               data_i,
    /* verilator lint_on UNUSEDSIGNAL */

    input logic [63:0]            tick_cntr_i
);

    logic [63:0] bandwidth_allocation;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            bandwidth_allocation <= '0;
        end
        else begin
            if (ack_rx_i)
                bandwidth_allocation <= '0;
            else if (rx_i)
                bandwidth_allocation <= bandwidth_allocation + 1;
        end
    end

////////////////////////////////////////////////////////////////////////////////
// Logging control
////////////////////////////////////////////////////////////////////////////////

    /**
     * This is ugly
     * The reason why we need to use open -> write -> close is because all other
     * routers, ports, and other modules can write to the same file
     * The only way to change it is to also change the graphical debugger to
     * read from different files for each router
     */

    int fd;

    always_ff @(posedge ack_rx_i) begin
        if (!data_i.clear) begin
            /* verilator lint_off BLKSEQ */
            fd = $fopen(FILE_NAME, "a");
            /* verilator lint_on BLKSEQ */

            if (fd == '0) begin
                $display("[TrafficBroadcast] Could not open log file");
                $finish();
            end

            $fwrite(
                fd, "%0d\t%0d\t%0x\t%0d\t%0d\t%0d\t%0d\n", 
                tick_cntr_i,
                ADDRESS, 
                data_i.ksvc, 
                1'b1, 
                bandwidth_allocation, 
                (PORT*2 + 1), 
                '1
            );

            $fflush(fd);
            $fclose(fd);
        end
    end

endmodule
