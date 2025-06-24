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

    /* We only use lower 32 bits */
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [63:0]            tick_cntr_i
    /* verilator lint_on UNUSEDSIGNAL */
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

    logic [31:0] flit_idx;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            flit_idx <= '0;
        end
        else begin
            if (mon_state == MON_RCV_HEADER)
                flit_idx <= 32'h00000001;
            else if (flit_received)
                flit_idx <= flit_idx + 1'b1;
        end
    end

    logic [63:0] bandwidth_allocation;
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

    logic [31:0] header_time;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            header_time <= '0;
        else if (mon_state == MON_RCV_HEADER)
            header_time <= tick_cntr_i[31:0];
    end

////////////////////////////////////////////////////////////////////////////////
// Flit 0 monitored variables
////////////////////////////////////////////////////////////////////////////////

    logic [15:0] target;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            target <= '0;
        else if (mon_state == MON_RCV_HEADER)
            target <= data_i[15:0];
    end

    logic [ 7:0] service;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            service <= '0;
        else if (mon_state == MON_RCV_HEADER)
            service <= data_i[23:16];
    end

////////////////////////////////////////////////////////////////////////////////
// Flit 2 monitored variables
////////////////////////////////////////////////////////////////////////////////

    /* 2 */
    logic [15:0] receiver;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            receiver <= '0;
        else if (flit_idx == 32'h00000002)
            receiver <= data_i[15:0];
    end

    logic [15:0] sender;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            sender <= '0;
        else if (flit_idx == 32'h00000002)
            sender <= data_i[31:16];
    end

////////////////////////////////////////////////////////////////////////////////
// Flit 4 monitored variables
////////////////////////////////////////////////////////////////////////////////

    logic [15:0] mig_task;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            mig_task <= '0;
        else if (flit_idx == 32'h00000004)
            mig_task <= data_i[15:0];
    end

////////////////////////////////////////////////////////////////////////////////
// Flit 5 monitored variables
////////////////////////////////////////////////////////////////////////////////

    logic [15:0] alloc_task;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            alloc_task <= '0;
        else if (flit_idx == 32'h00000005)
            alloc_task <= data_i[31:16];
    end

////////////////////////////////////////////////////////////////////////////////
// Logging control
////////////////////////////////////////////////////////////////////////////////

    logic write_mig_task;
    assign write_mig_task = service inside {
        MIGRATION_DATA
    };

    logic write_alloc_task;
    assign write_alloc_task = service inside {
        TASK_ALLOCATION
    };

    logic write_edge;
    assign write_edge = service inside {
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
                flit_idx, 
                bandwidth_allocation, 
                (PORT*2), 
                target
            );

            if (write_mig_task)
                $fwrite(fd, "\t%0d", mig_task);

            if (write_alloc_task)
                $fwrite(fd, "\t%0d", alloc_task);

            if (write_edge)
                $fwrite(fd, "\t%0d\t%0d", sender, receiver);

            $fwrite(fd, "\n");

            $fflush(fd);
            $fclose(fd);
        end
    end

endmodule
