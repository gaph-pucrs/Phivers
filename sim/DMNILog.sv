`include "../TaskInjector/rtl/TaskInjectorPkg.sv"

module DMNILog
    import TaskInjectorPkg::*;
#(
    parameter int           FLIT_SIZE = 32,
    parameter logic [15:0]  ADDRESS   = 16'h0000,
    parameter string        LOG_PATH  = "./debug/dmni"
)
(
    input logic                   clk_i,
    input logic                   rst_ni,

    input logic                   tx_i,
    input logic                   eop_i,
    input logic                   credit_i,
    input logic [(FLIT_SIZE-1):0] data_i,

    input logic [           63:0] tick_cntr_i
);

    string file = $sformatf("%s/%02dx%02d.csv", LOG_PATH, ADDRESS[15:8], ADDRESS[7:0]);
    int fd;

    initial begin
        fd = $fopen(file, "w");
        if (fd == '0) begin
            $display(
                "[%7.3f] [DMNILog %02dx%02d] Could not open log file %s", 
                $time()/1_000_000.0, 
                ADDRESS[15:8], 
                ADDRESS[7:0], 
                file
            );
            $finish();
        end
        $fwrite(fd, "timestamp,total_time,cons,prod,noc_time,size\n");
    end

////////////////////////////////////////////////////////////////////////////////

    typedef enum {
        HEADER,
        PAYLOAD
    } state_t;

    state_t state;
    state_t next_state;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            state <= HEADER;
        else
            state <= next_state;
    end

    logic flit_received;
    assign flit_received = tx_i && credit_i;

    logic last_flit_received;
    assign last_flit_received = flit_received && eop_i;

    always_comb begin
        case (state)
            HEADER:
                next_state = flit_received ? PAYLOAD : HEADER;
            PAYLOAD:
                next_state = last_flit_received ? HEADER : PAYLOAD;
            default:
                next_state = HEADER;
        endcase
    end

    logic [(FLIT_SIZE-1):0] flit_idx;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            flit_idx <= '0;
        else if (state == HEADER)
            flit_idx <= 32'h01;
        else if (flit_received)
            flit_idx <= flit_idx + 1'b1;
    end

    logic [63:0] then;
    logic [(FLIT_SIZE-1):0] service;
    logic [(FLIT_SIZE-1):0] producer;
    logic [(FLIT_SIZE-1):0] consumer;
    logic [(FLIT_SIZE-1):0] timestamp;
    
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            then <= '0;
        else if (state == HEADER)
            then <= tick_cntr_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            service <= '0;
        else if (flit_idx == 32'h02)
            service <= data_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            producer <= '0;
        else if (flit_idx == 32'h03)
            producer <= data_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            consumer <= '0;
        else if (flit_idx == 32'h04)
            consumer <= data_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            timestamp <= '0;
        else if (flit_idx == 32'h06)
            timestamp <= data_i;
    end

    always_ff @(posedge clk_i) begin
        if (last_flit_received && service == MESSAGE_DELIVERY) begin
            $fwrite(
                fd, 
                "%0d,%0d,%08x,%08x,%0d,%0d\n", 
                tick_cntr_i,                    /* Timestamp          */
                (tick_cntr_i - 64'(timestamp)), /* Total time         */
                consumer,
                producer,
                (then - 64'(timestamp)),        /* Time spent in NoC  */
                (flit_idx + 1'b1)               /* Message size       */
            );
        end
    end

////////////////////////////////////////////////////////////////////////////////

    final begin
        $fclose(fd);
    end

endmodule
