`include "../Hermes/rtl/HermesPkg.sv"
`include "../TaskInjector/rtl/TaskInjectorPkg.sv"

module TrafficRouter
    import HermesPkg::*;
    import TaskInjectorPkg::*;
#(
    parameter               FLIT_SIZE = 32,
    parameter logic [15:0]  ADDRESS   = 16'h0000,
    parameter hermes_port_t PORT      = HERMES_EAST,
    parameter string        FILE_NAME = "./debug/traffic_router.txt"
)
(
    input logic clk_i,
    input logic rst_ni,

    input logic                   rx_i,
    input logic                   credit_i,
    input logic [(FLIT_SIZE-1):0] data_i,

    input logic [63:0]            tick_cntr_i
);

    logic flit_received;
    assign flit_received = (rx_i && credit_i);

////////////////////////////////////////////////////////////////////////////////
// Monitor control
////////////////////////////////////////////////////////////////////////////////

    typedef enum logic [4:0] {
        MON_RCV_HEADER,
        MON_RCV_SIZE,
        MON_RCV_PAYLOAD
    } fsm_t;

    fsm_t mon_state;
    fsm_t mon_next_state;

    always_comb begin
        case (mon_state)
            MON_RCV_HEADER: 
                mon_next_state = flit_received ? MON_RCV_SIZE : MON_RCV_HEADER;
            MON_RCV_SIZE:
                mon_next_state = flit_received ? MON_RCV_PAYLOAD : MON_RCV_SIZE;
            MON_RCV_PAYLOAD:
                mon_next_state = (flit_received && flit_cntr == 32'd1)
                    ? MON_RCV_HEADER
                    : MON_RCV_PAYLOAD;
            default:
                mon_next_state = MON_RCV_HEADER;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            mon_state <= MON_RCV_HEADER;
        else
            mon_state <= mon_next_state;
    end

    logic message_received;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            message_received <= 1'b0;
        end
        else begin
            if (mon_state == MON_RCV_PAYLOAD && flit_received && flit_cntr == 32'd1)
                message_received <= 1'b1;
            else
                message_received <= 1'b0;
        end
    end

////////////////////////////////////////////////////////////////////////////////
// Monitored variables
////////////////////////////////////////////////////////////////////////////////

    logic [63:0] bandwidth_allocation;

    /* 0 */
    logic [15:0] target;
    logic [63:0] header_time;

    /* 1 */
    logic [31:0] size;
    logic [31:0] flit_cntr;
    logic [31:0] flit_idx;

    /* 2 */
    logic [31:0] service;

    /* 3 */
    logic [15:0] task_id;

    /* 4 */
    logic [15:0] cons_id;

    /* 13 */
    logic [31:0] dlvr_service;

    /* 14 */
    logic [15:0] dlvr_task_id;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            target <= '0;
        else if (mon_state == MON_RCV_HEADER)
            target <= data_i[15:0];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            header_time <= '0;
        else if (mon_state == MON_RCV_HEADER)
            header_time <= tick_cntr_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            bandwidth_allocation <= '0;
        end
        else begin
            if (mon_state == MON_RCV_HEADER)
                bandwidth_allocation <= '0;
            else
                bandwidth_allocation <= bandwidth_allocation + 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            flit_cntr <= '0;
        end
        else begin
            if (mon_state == MON_RCV_SIZE)
                flit_cntr <= data_i;
            else if (flit_received)
                flit_cntr <= flit_cntr - 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            flit_idx <= '0;
        end
        else begin
            if (mon_state == MON_RCV_SIZE)
                flit_idx <= 32'd2;
            else if (flit_received)
                flit_idx <= flit_idx + 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            size <= '0;
        else if (mon_state == MON_RCV_SIZE)
            size <= data_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            service <= '0;
        else if (flit_idx == 32'd2)
            service <= data_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            task_id <= '0;
        else if (flit_idx == 32'd3)
            task_id <= data_i[15:0];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            cons_id <= '0;
        else if (flit_idx == 32'd4)
            cons_id <= data_i[15:0];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            dlvr_service <= '0;
        else if (flit_idx == 32'd13)
            dlvr_service <= data_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            dlvr_task_id <= '0;
        else if (flit_idx == 32'd14)
            dlvr_task_id <= data_i[15:0];
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

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni) begin
            if (message_received) begin
                /* verilator lint_off BLKSEQ */
                fd = $fopen(FILE_NAME, "a");
                /* verilator lint_on BLKSEQ */

                if (fd == '0) begin
                    $display("[TrafficRouter] Could not open log file");
                end
                else begin
                    $fwrite(
                        fd, "%0d\t%0d\t%0x\t%0d\t%0d\t%0d\t%0d", 
                        header_time,
                        ADDRESS, 
                        service, 
                        size, 
                        bandwidth_allocation, 
                        (PORT*2), 
                        target
                    );

                    if (
                        service inside {
                            MESSAGE_REQUEST, 
                            MESSAGE_DELIVERY, 
                            DATA_AV, 
                            MIGRATION_DATA_BSS, 
                            TASK_ALLOCATION
                        }
                    ) begin
                        $fwrite(fd, "\t%0d", task_id);
                    end

                    if (
                        service inside {
                            MESSAGE_REQUEST, 
                            MESSAGE_DELIVERY, 
                            DATA_AV
                        }
                    ) begin
                        $fwrite(fd, "\t%0d", cons_id);
                    end

                    $fwrite(fd, "\n");

                    /* If it is a DELIVERY containing a service message, we may need to log it */
                    if (
                        service == MESSAGE_DELIVERY
                        && cons_id == '0 /* To mapper task */
                        && dlvr_service == TASK_TERMINATED
                    ) begin
                        $fwrite(
                            fd, "%0d\t%0d\t%0x\t%0d\t%0d\t%0d\t%0d\t%0d\n", 
                            header_time,
                            ADDRESS, 
                            dlvr_service, 
                            '0, 
                            '0, 
                            (PORT*2), 
                            target, 
                            dlvr_task_id
                        );
                    end

                    $fflush(fd);
                    $fclose(fd);
                end
            end
        end
    end

endmodule
