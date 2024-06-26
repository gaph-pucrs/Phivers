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
    input logic                   eop_i,
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
        MON_RCV_PAYLOAD
    } fsm_t;

    fsm_t mon_state;
    fsm_t mon_next_state;

    always_comb begin
        case (mon_state)
            MON_RCV_HEADER: 
                mon_next_state = flit_received ? MON_RCV_PAYLOAD : MON_RCV_HEADER;
            MON_RCV_PAYLOAD:
                mon_next_state = (flit_received && eop_i)
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
    assign message_received = (mon_state == MON_RCV_PAYLOAD && flit_received && eop_i);

////////////////////////////////////////////////////////////////////////////////
// Monitored variables
////////////////////////////////////////////////////////////////////////////////

    logic [63:0] bandwidth_allocation;

    /* 0 */
    logic [15:0] target;
    logic [63:0] header_time;

    /* 1 */
    logic [31:0] size;
    // flit_cntr too
    logic [31:0] flit_idx;

    /* 2 */
    logic [31:0] service;

    /* 3 */
    logic [15:0] task_id;

    /* 4 */
    logic [15:0] cons_id;

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
            flit_idx <= '0;
        end
        else begin
            if (mon_state == MON_RCV_HEADER)
                flit_idx <= 32'h01;
            else if (flit_received)
                flit_idx <= flit_idx + 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            size <= '0;
        else if (flit_idx == 32'd1)
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

////////////////////////////////////////////////////////////////////////////////
// Logging control
////////////////////////////////////////////////////////////////////////////////

    logic write_task_id;
    assign write_task_id = service inside {
        MESSAGE_REQUEST, 
        MESSAGE_DELIVERY, 
        DATA_AV, 
        MIGRATION_DATA_BSS, 
        TASK_ALLOCATION
    };

    logic write_cons_id;
    assign write_cons_id = service inside {
        MESSAGE_REQUEST, 
        MESSAGE_DELIVERY, 
        DATA_AV
    };

    /**
     * This is ugly
     * The reason why we need to use open -> write -> close is because all other
     * routers, ports, and other modules can write to the same file
     * The only way to change it is to also change the graphical debugger to
     * read from different files for each router
     */
    int fd;

    always_latch begin
        if (message_received) begin
            fd = $fopen(FILE_NAME, "a");

            if (fd == '0) begin
                $display("[TrafficRouter] Could not open log file");
                $finish();
            end
            
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

            if (write_task_id)
                $fwrite(fd, "\t%0d", task_id);

            if (write_cons_id)
                $fwrite(fd, "\t%0d", cons_id);

            $fwrite(fd, "\n");

            $fflush(fd);
            $fclose(fd);
        end
    end

endmodule
