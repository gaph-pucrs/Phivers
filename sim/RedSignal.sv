module RedSignal
    import TaskInjectorPkg::*;
#(
    parameter logic [15:0] ADDRESS  = 16'b0,
    parameter string       PORT     = ""
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        tx_i,
    output logic        cr_tx_o,
    input  logic        eop_tx_i,
    input  logic [31:0] data_tx_i,

    output logic        rx_o,
    input  logic        cr_rx_i,
    output logic        eop_rx_o,
    output logic [31:0] data_rx_o
);

    bit enabled;
    int unsigned tick_begin;
    int unsigned cycles_min;
    int unsigned cycles_max;
    int unsigned chance;
    logic [ 7:0] filter_app;
    logic [ 7:0] filter_prod;
    logic [ 7:0] filter_cons;

    int cfg;
    int log;
    initial begin
        cfg = $fopen($sformatf("link/rs%0dx%0d-%s.cfg", ADDRESS[15:8], ADDRESS[7:0], PORT), "r");
        if (cfg == '0) begin
            $display(
                "[%7.3f] [RS %02dx%02d-%s] Could not open configuration file. Disabling.", 
                $time()/1_000_000.0, 
                ADDRESS[15:8], 
                ADDRESS[7:0], 
                PORT
            );
            enabled = 0;
        end
        else begin
            enabled = 1;
            $fscanf(cfg, "%d", tick_begin );
            $fscanf(cfg, "%d", cycles_min );
            $fscanf(cfg, "%d", cycles_max );
            $fscanf(cfg, "%d", chance     );
            $fscanf(cfg, "%d", filter_app );
            $fscanf(cfg, "%d", filter_prod);
            $fscanf(cfg, "%d", filter_cons);
            $fclose(cfg);

            log = $fopen($sformatf("debug/link/rs%0dx%0d-%s.log", ADDRESS[15:8], ADDRESS[7:0], PORT), "w");
            $fwrite(log, "snd_time,ht_time,prod,cons,cycles\n");

            $display(
                "[%7.3f] [RS %02dx%02d-%s] Will hang for %0d to %0d cycles with %0d chance", 
                $time()/1_000_000.0, 
                ADDRESS[15:8], 
                ADDRESS[7:0], 
                PORT,
                cycles_min,
                cycles_max,
                chance
            );
        end
    end

    typedef enum {
        PASS,
        HEADER,
        SRCPE,
        EDGE,
        TIMESTAMP,
        HANG,
        EMPTY,
        EOP
    } rs_fsm_t;

    logic received;
    assign received = tx_i && cr_rx_i;

    rs_fsm_t state;
    rs_fsm_t next_state;

    logic [15:0] sender;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            sender <= '0;
        else if (state == EDGE)
            sender <= data_tx_i[31:16];
    end

    logic [15:0] receiver;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            receiver <= '0;
        else if (state == EDGE)
            receiver <= data_tx_i[15: 0];
    end

    logic [7:0] service;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            service <= '0;
        else if (state == HEADER)
            service <= data_tx_i[23:16];
    end

    logic should_start;
    assign should_start = (int'($time()/10) >= tick_begin);

    logic is_delivery;
    assign is_delivery  = (service == MESSAGE_DELIVERY);

    logic filter_match;
    assign filter_match = (
        (filter_app  == '1 || sender  [15:8] == filter_app) &&
        (filter_prod == '1 || sender  [ 7:0] == filter_prod) &&
        (filter_cons == '1 || receiver[ 7:0] == filter_cons)
    );

    int unsigned next_hang;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            next_hang <= $urandom_range(0, 99);
        else if (buf_recv && state == TIMESTAMP && filter_match)
            next_hang <= $urandom_range(0, 99);
    end

    logic should_hang;
    assign should_hang = (next_hang < chance);


    logic hang_finish;
    int unsigned hang_cycles;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            hang_cycles <= $urandom_range(cycles_min, cycles_max);
        else if (state == HANG)
            hang_cycles <= hang_finish ? $urandom_range(cycles_min, cycles_max) : hang_cycles - 1;
    end

    assign hang_finish = (hang_cycles == 0);

    logic buf_rx;
    logic buf_cr_rx;
    logic buf_tx;
    logic buf_cr_tx;
    logic buf_eop;
    logic [31:0] buf_data;
    RingBuffer #(
        .DATA_SIZE   (33),
        .BUFFER_SIZE ( 4)
    ) rb (
        .clk_i    (clk_i                ),
        .rst_ni   (rst_ni               ),
        .buf_rst_i(  1'b0               ),

        .rx_i     (buf_rx               ),
        .rx_ack_o (buf_cr_rx            ),
        .data_i   ({eop_tx_i, data_tx_i}),

        .tx_o     (buf_tx               ),
        .tx_ack_i (buf_cr_tx            ),
        .data_o   ({buf_eop,   buf_data})
    );

    logic buf_recv;
    assign buf_recv = buf_rx && buf_cr_rx;

    always_comb begin
        case (state)
            PASS:
                next_state = should_start                      ? EOP       : PASS;
            HEADER: begin
                next_state = buf_recv                          ? SRCPE     : HEADER;
            end
            SRCPE:  begin
                if (buf_recv)
                    next_state = is_delivery                   ? EDGE      : EMPTY;
                else
                    next_state = SRCPE;
            end
            EDGE:
                next_state = buf_recv                          ? TIMESTAMP : EDGE;
            TIMESTAMP: begin
                if (buf_recv)
                    next_state = (filter_match && should_hang) ? HANG      : EMPTY;
                else
                    next_state = TIMESTAMP;
            end
            HANG:
                next_state = hang_finish                       ? EMPTY     : HANG;
            EMPTY: begin
                if (!buf_tx)
                    next_state = EOP;
                else if (buf_eop && buf_cr_tx)
                    next_state = HEADER;
                else
                    next_state = EMPTY;
            end
            EOP:
                next_state = (received && eop_tx_i)            ? HEADER    : EOP;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            state <= PASS;
        else if (enabled)
            state <= next_state;
    end

    logic [31:0] timestamp;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            timestamp <= '0;
        else if (state == TIMESTAMP)
            timestamp <= data_tx_i;
    end

    logic logged;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            logged <= 1'b0;
        end
        if (!logged && state == HANG) begin
            logged <= 1'b1;
            // snd_time,ht_time,prod,cons,cycles
            $fwrite(
                log, 
                "%0d,%0d,%0d,%0d,%0d\n",
                timestamp, 
                int'($time()/10), 
                sender, 
                receiver, 
                hang_cycles
            );
        end
        else if (state != HANG) begin
            logged <= 1'b0;
        end
    end


    always_comb begin
        case (state)
            EOP,
            PASS:
                rx_o = tx_i;
            EMPTY:
                rx_o = buf_tx;
            default:
                rx_o = 1'b0;
        endcase
    end

    always_comb begin
        case (state)
            EOP,
            PASS:
                cr_tx_o = cr_rx_i;
            EDGE,
            SRCPE,
            HEADER,
            TIMESTAMP:
                cr_tx_o = buf_cr_rx;
            default:
                cr_tx_o = 1'b0;
        endcase
    end

    always_comb begin
        case (state)
            EDGE,
            SRCPE,
            HEADER,
            TIMESTAMP:
                buf_rx = tx_i;
            default:
                buf_rx = 1'b0;
        endcase
    end

    always_comb begin
        case (state)
            EMPTY:
                buf_cr_tx = cr_rx_i;
            default:
                buf_cr_tx = 1'b0;
        endcase
    end

    always_comb begin
        case (state)
            EMPTY:
                data_rx_o = buf_data;
            default:
                data_rx_o = data_tx_i;
        endcase
    end

    always_comb begin
        case (state)
            EMPTY:
                eop_rx_o = buf_eop;
            default:
                eop_rx_o = eop_tx_i;
        endcase
    end

    final begin
        $fclose(log);
    end

endmodule
