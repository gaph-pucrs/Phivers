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
        $fwrite(fd, "snd_time,noc_time,rcv_time,size,prod,cons\n");
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
            flit_idx <= 32'h00000001;
        else if (flit_received)
            flit_idx <= flit_idx + 1'b1;
    end

    logic [ 7:0] service;
    logic [15:0] sender;
    logic [15:0] receiver;
    logic [31:0] timestamp;
    logic [31:0] then;
    
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            then <= '0;
        else if (state == HEADER)
            then <= tick_cntr_i[31:0];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            service <= '0;
        else if (state == HEADER)
            service <= data_i[23:16];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            sender <= '0;
        else if (flit_idx == 32'h02)
            sender <= data_i[31:16];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            receiver <= '0;
        else if (flit_idx == 32'h02)
            receiver <= data_i[15:0];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            timestamp <= '0;
        else if (flit_idx == 32'h03)
            timestamp <= data_i;
    end

    always_ff @(posedge clk_i) begin
        if (last_flit_received && service == MESSAGE_DELIVERY) begin
            // snd_time,noc_time,rcv_time,size,prod,cons
            $fwrite(
                fd, 
                "%0d,%0d,%0d,%0d,%04x,%04x\n", 
                timestamp,                     /* Send timestamp     */
                then,                          /* Wormhole timestamp */
                tick_cntr_i,                   /* Receive timestamp  */
                (flit_idx + 1'b1),             /* Message size       */
                sender,                        /* Producer ID        */
                receiver                       /* Consumer ID        */
            );
        end
    end

////////////////////////////////////////////////////////////////////////////////

    final begin
        $fclose(fd);
    end

endmodule
